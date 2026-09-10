import * as admin from "firebase-admin";
import express from "express";
import {onRequest} from "firebase-functions/https";
import {setGlobalOptions} from "firebase-functions/options";

admin.initializeApp();
setGlobalOptions({maxInstances: 5});

const db = admin.firestore();

const app = express();

export {app};

const requireAuth: express.RequestHandler = async (req, res, next) => {
  const authHeader = req.get("Authorization");

  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({error: "Token não fornecido ou formato inválido."});
    return;
  }

  try {
    res.locals.user = await admin.auth().verifyIdToken(authHeader.slice(7));
    next();
  } catch {
    res.status(401).json({error: "Token de autenticação inválido."});
  }
};

app.use(express.json());
app.use(requireAuth);

app.post("/prescriptions/validate", (req, res) => {
  const {reference} = req.body;

  if (!reference) {
    res.status(400).json({
      error: "reference is required",
    });
    return;
  }

  res.status(200).json({
    isValid: true,
  });
});

app.get("/medications/:ean/eligibility", (req, res) => {
  res.status(200).json({
    isEligible: true,
  });
});

app.post("/checkouts", async (req, res) => {
  try {
    const {id, availableBalanceInCents, prescription, medications} = req.body;
    const idempotencyKey = req.header("Idempotency-Key");

    if (!idempotencyKey) {
      res.status(400).json({error: "Idempotency-Key header is required"});
      return;
    }

    const requesterId = res.locals.user.uid;

    const checkoutRef = db.collection("checkouts").doc(idempotencyKey);
    const existingCheckout = await checkoutRef.get();
    const existingOwnerId = existingCheckout.data()?.userId;

    // O atalho de idempotência também precisa autorizar: sem esta checagem,
    // enviar a chave de outra pessoa devolveria o identificador do checkout
    // dela, e o remetente passaria a operar sobre um recurso que não é seu.
    if (existingCheckout.exists && existingOwnerId !== requesterId) {
      res.status(404).json({error: "Checkout not found"});
      return;
    }

    if (existingCheckout.exists) {
      res.status(200).json({id: checkoutRef.id});
      return;
    }

    await checkoutRef.set({
      id,
      availableBalanceInCents,
      prescription,
      medications,
      status: "awaitingConfirmation",
      userId: res.locals.user.uid,
    });

    res.status(201).json({id: checkoutRef.id});
  } catch (error) {
    console.error("Failed to create checkout:", error);
    res.status(500).json({error: "Internal server error"});
  }
});

app.get("/checkouts/:remoteCheckoutId", async (req, res) => {
  try {
    const userId = res.locals.user.uid;
    const {remoteCheckoutId} = req.params;

    const checkoutSnapshot = await db
      .collection("checkouts")
      .doc(remoteCheckoutId)
      .get();

    if (!checkoutSnapshot.exists) {
      res.status(404).json({
        error: "Checkout not found",
      });
      return;
    }

    const checkout = checkoutSnapshot.data();

    // Falha fechado: documento sem dados, ou gravado antes desta aula e
    // portanto sem dono registrado, é tratado como inexistente. E dono
    // diferente responde 404, e não 403, para não confirmar a existência do
    // recurso a quem não é dele.
    if (checkout === undefined || checkout.userId !== userId) {
      res.status(404).json({
        error: "Checkout not found",
      });
      return;
    }

    // O dono fica de fora da resposta: quem pede já sabe quem é, e expor o
    // identificador interno sem que ninguém precise dele é custo sem ganho.
    const {userId: _owner, ...checkoutWithoutOwner} = checkout;

    res.status(200).json({
      ...checkoutWithoutOwner,
      status: "paid",
    });
  } catch (error) {
    console.error("Failed to get checkout:", error);

    res.status(500).json({
      error: "Internal server error",
    });
  }
});

export const api = onRequest(app);
