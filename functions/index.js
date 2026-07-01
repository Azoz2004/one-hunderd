const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

exports.sendPokeNotification = onDocumentUpdated("competitive_sessions/{sessionId}", async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();

  if (!beforeData || !afterData) return;

  // Participant UIDs
  const uids = [afterData.participant1Uid, afterData.participant2Uid].filter(Boolean);
  
  for (const uid of uids) {
    const pokeField = `poke_to_${uid}`;
    const beforePoke = beforeData[pokeField];
    const afterPoke = afterData[pokeField];
    
    // If the poke field was added or changed (meaning a new poke happened)
    if (afterPoke && afterPoke !== beforePoke) {
      // Find the partner who sent the poke
      const partnerUid = uid === afterData.participant1Uid ? afterData.participant2Uid : afterData.participant1Uid;
      const partnerName = partnerUid === afterData.participant1Uid ? afterData.participant1Name : afterData.participant2Name;
      
      logger.info(`Poke detected from ${partnerName} to user ${uid}`);

      // Fetch the FCM token for the target user
      try {
        const userDoc = await admin.firestore().collection('users').doc(uid).get();
        if (!userDoc.exists) continue;
        
        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;
        
        if (!fcmToken) {
          logger.info(`No FCM token found for user ${uid}`);
          continue;
        }

        const message = {
          token: fcmToken,
          notification: {
            title: "👇 لكزك خصمك!",
            body: `نكزك ${partnerName || 'خصمك'} ليذكّرك بالإيداع اليومي!\nلا تدعه يتقدم عليك 🏆`,
          },
          data: {
            type: "poke",
            sessionId: event.params.sessionId,
            pokerId: partnerUid,
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'friends_channel',
              sound: 'default'
            }
          }
        };

        const response = await admin.messaging().send(message);
        logger.info(`Successfully sent poke notification to ${uid}: ${response}`);
      } catch (error) {
        logger.error(`Error sending poke notification to ${uid}:`, error);
      }
    }
  }
});
