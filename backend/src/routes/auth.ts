// Rotas públicas de autenticação. O Firebase Admin cria usuários, enquanto a
// API REST do Firebase Auth devolve tokens utilizáveis pelo aplicativo.
import express, { Request, Response } from 'express';
import { auth } from '../config/firebase';
import { AppError } from '../middleware/errorHandler';
import {
  deleteInitializedUserProfile,
  initializeUserProfile,
} from '../services/userProfileService';
import {
  isValidEmail,
  isValidCPF,
  isValidPhoneNumber,
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

/** Autentica e devolve ID token e refresh token do Firebase. */
async function signInWithPassword(
  email: string,
  password: string
): Promise<FirebasePasswordAuthResponse> {
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!apiKey) {
    throw new AppError(500, 'Variável de ambiente FIREBASE_API_KEY ausente');
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
    throw new AppError(401, 'E-mail ou senha inválidos');
  }

  return data as FirebasePasswordAuthResponse;
}

/** Solicita ao Firebase o envio do link de redefinição de senha. */
async function sendPasswordResetEmail(email: string): Promise<void> {
  const apiKey = process.env.FIREBASE_API_KEY;

  if (!apiKey) {
    throw new AppError(500, 'Variável de ambiente FIREBASE_API_KEY ausente');
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
    throw new AppError(400, 'Não foi possível enviar o e-mail de recuperação de senha');
  }
}

// Cria a conta no Auth e os documentos auxiliares no Firestore.
router.post('/register', async (req: Request, res: Response, next: any) => {
  let createdUserUid: string | null = null;

  try {
    const { email, password, nomeCompleto, cpf, telefone } = req.body as RegisterRequest;

    if (!email || !password || !nomeCompleto || !cpf || !telefone) {
      throw new AppError(400, 'Campos obrigatórios ausentes');
    }

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail inválido');
    }

    if (!isValidCPF(cpf)) {
      throw new AppError(400, 'CPF inválido');
    }

    if (!isValidPhoneNumber(telefone)) {
      throw new AppError(400, 'Telefone inválido');
    }

    if (password.length < 6) {
      throw new AppError(400, 'A senha deve ter pelo menos 6 caracteres');
    }

    if (!process.env.FIREBASE_API_KEY) {
      throw new AppError(500, 'Variável de ambiente FIREBASE_API_KEY ausente');
    }

    const userRecord = await auth().createUser({
      email,
      password,
      displayName: nomeCompleto,
    });
    createdUserUid = userRecord.uid;

    const authResult = await signInWithPassword(email, password);

    await initializeUserProfile({
      uid: userRecord.uid,
      nomeCompleto,
      email,
      cpf,
      telefone,
    });

    res.status(201).json({
      uid: userRecord.uid,
      email: userRecord.email,
      token: authResult.idToken,
      refreshToken: authResult.refreshToken,
      expiresIn: authResult.expiresIn,
    });
  } catch (error) {
    // Compensa um cadastro interrompido para não deixar usuário órfão no Auth.
    if (createdUserUid) {
      await deleteInitializedUserProfile(createdUserUid, req.body?.cpf ?? '').catch(() => undefined);
      await auth().deleteUser(createdUserUid).catch(() => undefined);
    }

    next(error);
  }
});

// Autentica uma conta existente.
router.post('/login', async (req: Request, res: Response, next: any) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      throw new AppError(400, 'E-mail e senha são obrigatórios');
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

// Valida a existência do usuário antes de pedir o e-mail de recuperação.
router.post('/forgot-password', async (req: Request, res: Response, next: any) => {
  try {
    const { email } = req.body;

    if (!email) {
      throw new AppError(400, 'E-mail é obrigatório');
    }

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail inválido');
    }

    try {
      await auth().getUserByEmail(email);
    } catch (error: any) {
      if (error.code === 'auth/user-not-found') {
        throw new AppError(404, 'Usuário com este e-mail não encontrado');
      }
      throw error;
    }

    await sendPasswordResetEmail(email);

    res.json({
      message: 'O link de recuperação de senha foi enviado para o seu e-mail',
      email,
    });
  } catch (error) {
    next(error);
  }
});

export default router;
