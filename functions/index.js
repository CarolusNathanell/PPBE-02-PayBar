const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// Helper: kirim FCM + simpan ke inbox Firestore
async function sendAndSaveNotification({ uid, title, body, type, groupId }) {
  // 1) Simpan ke inbox notifikasi user
  await db.collection("users").doc(uid).collection("notifications").add({
    title,
    body,
    type,    
    groupId: groupId ?? null,
    isRead: false,
    createdAt: new Date(),
  });

  // 2) Ambil FCM token user
  const userDoc = await db.collection("users").doc(uid).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return;

  // 3) Kirim push notification
  await getMessaging().send({
    token,
    notification: { title, body },
    android: {
      notification: {
        channelId: "paybar_channel",
        priority: "high",
      },
    },
  });
}

// Trigger 1: Transaksi baru di grup
exports.onNewTransaction = onDocumentCreated(
  "groups/{groupId}/transactions/{txId}",
  async (event) => {
    const tx = event.data.data();
    const { groupId } = event.params;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "sebuah grup";
    const members = groupDoc.data()?.members ?? [];

    // Ambil nama payer
    const payerDoc = await db.collection("users").doc(tx.paidBy).get();
    const payerName = payerDoc.data()?.name ?? "Seseorang";

    const title = "Tagihan Baru! 🧾";
    const body = `${payerName} nambahin "${tx.description}" Rp${tx.amount.toLocaleString()} di grup ${groupName}`;

    // Notif ke semua member kecuali payer sendiri
    const targets = members.filter((uid) => uid !== tx.paidBy);
    await Promise.all(
      targets.map((uid) =>
        sendAndSaveNotification({ uid, title, body, type: "transaction", groupId })
      )
    );
  }
);

// Trigger 2: Settlement baru di grup
exports.onNewSettlement = onDocumentCreated(
  "groups/{groupId}/settlements/{settlementId}",
  async (event) => {
    const settlement = event.data.data();
    const { groupId } = event.params;

    const groupDoc = await db.collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "sebuah grup";

    const fromDoc = await db.collection("users").doc(settlement.fromUid).get();
    const fromName = fromDoc.data()?.name ?? "Seseorang";

    const title = "Hutang Dibayar! 💸";
    const body = `${fromName} udah bayar Rp${settlement.amount.toLocaleString()} di grup ${groupName}`;

    // Notif ke penerima (toUid)
    await sendAndSaveNotification({
      uid: settlement.toUid,
      title,
      body,
      type: "settlement",
      groupId,
    });
  }
);