const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure Nodemailer
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: "emarube89@gmail.com",
    pass: "SaEsLeElEl#1920", // use App Password from Gmail
  },
});

exports.sendVerificationEmail = functions.https.onCall(async (data) => {
  const { email, uid } = data;

  // Generate 6-digit verification code
  const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

  // Store code in Firestore with 2-minute expiration
  const expiration = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 2 * 60 * 1000)
  );

  await admin.firestore()
    .collection("users")
    .doc(uid)
    .collection("verification_codes")
    .doc(verificationCode)
    .set({
      code: verificationCode,
      email,
      expiresAt: expiration,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  // Email the code
  const mailOptions = {
    from: "emarube89@gmail.com",
    to: email,
    subject: "Your TaskMaster Verification Code",
    html: `
      <p>Here is your TaskMaster email verification code:</p>
      <h2>${verificationCode}</h2>
      <p>This code expires in 2 minutes.</p>
    `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error("Error sending verification email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});
