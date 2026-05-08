import admin from 'firebase-admin';

export function initializeFirebase() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n');
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

  if (!projectId || !privateKey || !clientEmail) {
    throw new Error('Configuracao do Firebase ausente nas variaveis de ambiente');
  }

  admin.initializeApp({
    credential: admin.credential.cert({
      projectId,
      privateKey,
      clientEmail,
    }),
  });
}

export const auth = (): admin.auth.Auth => admin.auth();
export const db = (): admin.firestore.Firestore => admin.firestore();
export const FieldValue = admin.firestore.FieldValue;
