import admin from 'firebase-admin';

export function initializeFirebase() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

  if (projectId && privateKey && clientEmail) {
    return admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey,
        clientEmail,
      }),
    });
  }

  return admin.initializeApp(projectId ? { projectId } : undefined);
}

export const auth = (): admin.auth.Auth => {
  initializeFirebase();
  return admin.auth();
};

export const db = (): admin.firestore.Firestore => {
  initializeFirebase();
  return admin.firestore();
};

export const FieldValue = admin.firestore.FieldValue;
