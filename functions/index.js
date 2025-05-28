/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {onRequest} = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");


admin.initializeApp();

// Configure Nodemailer (replace with your email service credentials)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "emarube89@gmail.com", // Replace with your Gmail
    pass: "SaEsLeElEl#1920", // Use an App Password from Google
  },
});

exports.sendVerificationEmail = functions.https.onCall(async (data) => {
  const {email, token, uid} = data;

  // Store token in Firestore with 2-minute expiration
  const expiration = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 2 * 60 * 1000), // 2 minutes from now
  );
  await admin.firestore()
      .collection("users")
      .doc(uid)
      .collection("verification_tokens")
      .doc(token)
      .set({
        token,
        email,
        expiresAt: expiration,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

  // Create verification link
  const verificationLink =
      `https://taskmaster-a103f.firebaseapp.com/verify?token=${token}&uid=${uid}`;

  // Email content
  const mailOptions = {
    from: "emarube89@gmail.com",
    to: email,
    subject: "Verify Your TaskMaster Email",
    html: `
      <p>Please verify your email by clicking the link below:</p>
      <a href="${verificationLink}">Verify Email</a>
      <p>This link expires in 2 minutes.</p>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return {success: true};
  } catch (error) {
    console.error("Error sending email:", error);
    throw new functions.https.HttpsError("Failed to send verification email");
  }
});
