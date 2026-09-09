import request from "supertest";

const validToken = "valid-token";
const authorization = `Bearer ${validToken}`;

jest.mock("firebase-admin", () => {
  const store = new Map<string, Record<string, unknown>>();

  return {
    initializeApp: jest.fn(),

    auth: () => ({
      // Aceita um único token conhecido e rejeita qualquer outro, imitando
      // o comportamento do Admin SDK, que lança quando o token é inválido
      // ou expirado em vez de devolver um resultado negativo.
      verifyIdToken: async (token: string) => {
        if (token !== "valid-token") {
          throw new Error("Firebase ID token has invalid signature.");
        }

        return {uid: "user-01"};
      },
    }),

    firestore: () => ({
      collection: () => ({
        doc: (id?: string) => {
          const docId = id ?? `generated-${store.size}`;

          return {
            id: docId,

            get: async () => ({
              exists: store.has(docId),
              data: () => store.get(docId),
            }),

            set: async (data: Record<string, unknown>) => {
              store.set(docId, data);
            },
          };
        },
      }),
    }),
  };
});

import {app} from "./index";

describe("API", () => {
  describe("autenticação", () => {
    it("returns 401 when the Authorization header is missing", async () => {
      const response = await request(app).get("/medications/ABC/eligibility");

      expect(response.status).toBe(401);
    });

    it("returns 401 when the header is not a Bearer token", async () => {
      const response = await request(app)
        .get("/medications/ABC/eligibility")
        .set("Authorization", validToken);

      expect(response.status).toBe(401);
    });

    it("returns 401 when the token is rejected", async () => {
      const response = await request(app)
        .get("/medications/ABC/eligibility")
        .set("Authorization", "Bearer expired-token");

      expect(response.status).toBe(401);
    });

    it("protects every route, not only the ones that write", async () => {
      const responses = await Promise.all([
        request(app).post("/prescriptions/validate").send({reference: "RX-01"}),
        request(app).get("/medications/ABC/eligibility"),
        request(app).post("/checkouts").set("Idempotency-Key", "k").send({}),
        request(app).get("/checkouts/any-id"),
      ]);

      for (const response of responses) {
        expect(response.status).toBe(401);
      }
    });
  });

  describe("POST /prescriptions/validate", () => {
    it("returns 400 when reference is missing", async () => {
      const response = await request(app)
        .post("/prescriptions/validate")
        .set("Authorization", authorization)
        .send({});

      expect(response.status).toBe(400);
    });

    it("returns isValid true when reference is provided", async () => {
      const response = await request(app)
        .post("/prescriptions/validate")
        .set("Authorization", authorization)
        .send({
          reference: "prescription-01",
        });

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        isValid: true,
      });
    });
  });

  describe("GET /medications/:ean/eligibility", () => {
    it("returns isEligible true", async () => {
      const response = await request(app)
        .get("/medications/ABC/eligibility")
        .set("Authorization", authorization);

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        isEligible: true,
      });
    });
  });

  describe("POST /checkouts", () => {
    const checkoutPayload = {
      id: "checkout-local-01",
      availableBalanceInCents: 1000,
      prescription: null,
      medications: [],
    };

    it("returns 400 when Idempotency-Key is missing", async () => {
      const response = await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .send(checkoutPayload);

      expect(response.status).toBe(400);
    });

    it("creates a checkout and returns 201 with its id", async () => {
      const response = await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .set("Idempotency-Key", "key-create-01")
        .send(checkoutPayload);

      expect(response.status).toBe(201);
      expect(response.body).toEqual({
        id: "key-create-01",
      });
    });

    it("deduplicates retries using Idempotency-Key", async () => {
      const idempotencyKey = "key-retry-01";

      const firstResponse = await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .set("Idempotency-Key", idempotencyKey)
        .send(checkoutPayload);

      const secondResponse = await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .set("Idempotency-Key", idempotencyKey)
        .send(checkoutPayload);

      expect(firstResponse.status).toBe(201);
      expect(secondResponse.status).toBe(200);

      expect(firstResponse.body).toEqual({
        id: idempotencyKey,
      });

      expect(secondResponse.body).toEqual({
        id: idempotencyKey,
      });

      expect(secondResponse.body.id).toBe(firstResponse.body.id);
    });

    it("keeps the request body intact after authentication", async () => {
      const idempotencyKey = "key-body-01";

      await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .set("Idempotency-Key", idempotencyKey)
        .send(checkoutPayload);

      const response = await request(app)
        .get(`/checkouts/${idempotencyKey}`)
        .set("Authorization", authorization);

      expect(response.body).toEqual({
        ...checkoutPayload,
        status: "paid",
      });
    });
  });

  describe("GET /checkouts/:remoteCheckoutId", () => {
    it("returns 404 when checkout does not exist", async () => {
      const response = await request(app)
        .get("/checkouts/non-existent-checkout")
        .set("Authorization", authorization);

      expect(response.status).toBe(404);
    });

    it("returns an existing checkout with paid status", async () => {
      const idempotencyKey = "key-get-01";

      const checkoutPayload = {
        id: "checkout-local-02",
        availableBalanceInCents: 2500,
        prescription: {
          reference: "prescription-01",
        },
        medications: [
          {
            ean: "7891234567890",
          },
        ],
      };

      const createResponse = await request(app)
        .post("/checkouts")
        .set("Authorization", authorization)
        .set("Idempotency-Key", idempotencyKey)
        .send(checkoutPayload);

      expect(createResponse.status).toBe(201);

      const response = await request(app)
        .get(`/checkouts/${idempotencyKey}`)
        .set("Authorization", authorization);

      expect(response.status).toBe(200);

      expect(response.body).toEqual({
        ...checkoutPayload,
        status: "paid",
      });
    });
  });
});
