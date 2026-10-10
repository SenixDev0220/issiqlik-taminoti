const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

// Sends an FCM push for every new document in the `notifications` collection.
// Empty recipientIds = broadcast to the `all` topic (every device subscribes
// to it on login); otherwise sends to the recipients' saved fcmTokens.
exports.sendNotificationPush = onDocumentCreated(
    "notifications/{id}",
    async (event) => {
      const data = event.data ? event.data.data() : null;
      if (!data) return;

      const title = data.title || "Issiqlik Ta'minoti";
      const body = data.message || "";
      const recipients = Array.isArray(data.recipientIds) ?
        data.recipientIds : [];

      const android = {notification: {channelId: "issiqlik_main"}};

      if (recipients.length === 0) {
        await getMessaging().send({
          topic: "all",
          notification: {title, body},
          android,
        });
        return;
      }

      const db = getFirestore();
      // Safety cap: sendEachForMulticast accepts max 500 tokens per call.
      const snaps = await db.getAll(
          ...recipients.slice(0, 500)
              .map((uid) => db.collection("users").doc(uid)),
      );
      const tokens = snaps
          .map((s) => s.get("fcmToken"))
          .filter((t) => typeof t === "string" && t.length > 0);

      if (tokens.length > 0) {
        await getMessaging().sendEachForMulticast({
          tokens,
          notification: {title, body},
          android,
        });
      }
    },
);

// Applies admin-initiated password resets. The app writes
// passwordResets/{uid} with a newPassword field; this function performs the
// actual Firebase Auth password change and deletes the doc so the plaintext
// password does not linger in Firestore.
exports.applyPasswordReset = onDocumentCreated(
    "passwordResets/{uid}",
    async (event) => {
      if (!event.data) return;
      const data = event.data.data();
      try {
        if (data && typeof data.newPassword === "string" &&
            data.newPassword.length >= 6) {
          await getAuth().updateUser(event.params.uid, {
            password: data.newPassword,
          });
        }
      } finally {
        await event.data.ref.delete();
      }
    },
);
