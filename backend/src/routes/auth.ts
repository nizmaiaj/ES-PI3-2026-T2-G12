import express, { Request, Response } from 'express';
import { auth, db, FieldValue } from '../config/firebase';
import { AppError } from '../middleware/errorHandler';
import {
  isValidEmail,
  isValidCPF,
  isValidPhoneNumber,
  sanitizeCPF,
  sanitizePhoneNumber,
} from '../utils/validation';

const router = express.Router();
const FIREBASE_AUTH_REST_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword';
const FIREBASE_PASSWORD_RESET_URL =
  'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode';

interface RegisterRequest {
  email: string;
  password: string;
  nomeCompleto: string;
  cpf: string;
  telefone: string;
}

interface FirebasePasswordAuthResponse {
  idToken: string;
  refreshToken: string;
  expiresIn: string;
  localId: string;
  email: string;
}

async function signInWithPassword(
  email: string,
  password: string
): Promise<FirebasePasswordAuthResponse> {
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!apiKey) {
    throw new AppError(500, 'Variavel de ambiente FIREBASE_API_KEY ausente');
  }

  const response = await fetch(`${FIREBASE_AUTH_REST_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email,
      password,
      returnSecureToken: true,
    }),
  });

  const data = await response.json();

  if (!response.ok) {
    throw new AppError(401, 'E-mail ou senha invalidos');
  }

  return data as FirebasePasswordAuthResponse;
}

async function sendPasswordResetEmail(email: string): Promise<void> {
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!apiKey) {
    throw new AppError(500, 'Variavel de ambiente FIREBASE_API_KEY ausente');
  }

  const response = await fetch(`${FIREBASE_PASSWORD_RESET_URL}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      requestType: 'PASSWORD_RESET',
      email,
    }),
  });

  if (!response.ok) {
    throw new AppError(400, 'Nao foi possivel enviar o e-mail de recuperacao de senha');
  }
}

router.post('/register', async (req: Request, res: Response, next: any) => {
  let createdUserUid: string | null = null;

  try {
    const { email, password, nomeCompleto, cpf, telefone } = req.body as RegisterRequest;

    if (!email || !password || !nomeCompleto || !cpf || !telefone) {
      throw new AppError(400, 'Campos obrigatorios ausentes');
    }

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail invalido');
    }

    if (!isValidCPF(cpf)) {
      throw new AppError(400, 'CPF invalido');
    }

    if (!isValidPhoneNumber(telefone)) {
      throw new AppError(400, 'Telefone invalido');
    }

    if (password.length < 6) {
      throw new AppError(400, 'A senha deve ter pelo menos 6 caracteres');
    }

    if (!process.env.FIREBASE_API_KEY) {
      throw new AppError(500, 'Variavel de ambiente FIREBASE_API_KEY ausente');
    }

    const userRecord = await auth().createUser({
      email,
      password,
      displayName: nomeCompleto,
    });
    createdUserUid = userRecord.uid;

    const sanitizedCPF = sanitizeCPF(cpf);
    const sanitizedPhone = sanitizePhoneNumber(telefone);

    const firebaseDb = db();
    const batch = firebaseDb.batch();

    const userDocRef = firebaseDb.collection('users').doc(userRecord.uid);
    batch.set(userDocRef, {
      uid: userRecord.uid,
      nomeCompleto,
      email,
      cpf: sanitizedCPF,
      telefone: sanitizedPhone,
      mfaHabilitado: false,
      mfaSecret: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const walletDocRef = firebaseDb.collection('wallets').doc(userRecord.uid);
    const INITIAL_BALANCE = 1000.0;
    batch.set(walletDocRef, {
      userId: userRecord.uid,
      saldoReais: INITIAL_BALANCE,
      updatedAt: FieldValue.serverTimestamp(),
    });

    await batch.commit();

    const authResult = await signInWithPassword(email, password);

    res.status(201).json({
      uid: userRecord.uid,
      email: userRecord.email,
      token: authResult.idToken,
      refreshToken: authResult.refreshToken,
      expiresIn: authResult.expiresIn,
    });
  } catch (error) {
    if (createdUserUid) {
      const firebaseDb = db();
      const cleanupBatch = firebaseDb.batch();
      cleanupBatch.delete(firebaseDb.collection('users').doc(createdUserUid));
      cleanupBatch.delete(firebaseDb.collection('wallets').doc(createdUserUid));
      await cleanupBatch.commit().catch(() => undefined);
      await auth().deleteUser(createdUserUid).catch(() => undefined);
    }

    next(error);
  }
});

router.post('/login', async (req: Request, res: Response, next: any) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      throw new AppError(400, 'E-mail e senha sao obrigatorios');
    }

    const authResult = await signInWithPassword(email, password);

    res.json({
      uid: authResult.localId,
      email: authResult.email,
      token: authResult.idToken,
      refreshToken: authResult.refreshToken,
      expiresIn: authResult.expiresIn,
    });
  } catch (error: any) {
    next(error);
  }
});

router.post('/forgot-password', async (req: Request, res: Response, next: any) => {
  try {
    const { email } = req.body;

    if (!email) {
      throw new AppError(400, 'E-mail e obrigatorio');
    }

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail invalido');
    }

    try {
      await auth().getUserByEmail(email);
    } catch (error: any) {
      if (error.code === 'auth/user-not-found') {
        throw new AppError(404, 'Usuario com este e-mail nao encontrado');
      }
      throw error;
    }

    await sendPasswordResetEmail(email);

    res.json({
      message: 'O link de recuperacao de senha foi enviado para o seu e-mail',
      email,
    });
  } catch (error) {
    next(error);
  }
});

export default router;
