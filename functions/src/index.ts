import * as admin from "firebase-admin";
import express from "express";
import {onRequest} from "firebase-functions/https";

admin.initializeApp();

const db = admin.firestore();

const app = express();

export {app};

app.use(express.json());

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

    const checkoutRef = db.collection("checkouts").doc(idempotencyKey);
    const existingCheckout = await checkoutRef.get();

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
    });

    res.status(201).json({id: checkoutRef.id});
  } catch (error) {
    console.error("Failed to create checkout:", error);
    res.status(500).json({error: "Internal server error"});
  }
});

app.get("/checkouts/:remoteCheckoutId", async (req, res) => {
  try {
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

    res.status(200).json({
      ...checkout,
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
