const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Configure Nodemailer with environment variables
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().gmail.user, // Set in Firebase Environment Config
    pass: functions.config().gmail.pass, // Set in Firebase Environment Config
  },
});

exports.sendVerificationEmail = functions.https.onRequest(async (req, res) => {
  // Ensure it's a POST request
  if (req.method !== "POST") {
    return res.status(405).json({error: "Method not allowed"});
  }

  const {data} = req.body;
  if (!data || !data.email || !data.uid || !data.token) {
    return res.status(400).json({error: "Missing email, uid, or token"});
  }

  const {email, uid, token} = data;

  // Store token in Firestore with 3-hour expiration
  const expiration = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 3 * 60 * 60 * 1000), // 3 hours
  );

  try {
    await admin
        .firestore()
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
    const verificationLink = `https://taskmaster-a103f.web.app/verify?uid=${uid}&token=${token}`;

    // Email the verification link
    const mailOptions = {
      from: functions.config().gmail.user,
      to: email,
      subject: "Verify Your TaskMaster Account",
      html: `
        <p>Welcome to TaskMaster!</p>
        <p>Please verify your email by clicking the link below:</p>
        <a href="${verificationLink}">Verify Email</a>
        <p>This link expires in 24 hours.</p>
        <p>If you didn't request this, please ignore this email.</p>
      `,
    };

    await transporter.sendMail(mailOptions);
    return res.status(200).json({success: true});
  } catch (error) {
    console.error("Error sending verification email:", error);
    return res.status(500).json({error: `Failed to send email: 
      ${error.message}`});
  }
});
