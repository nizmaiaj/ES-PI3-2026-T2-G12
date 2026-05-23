import crypto from 'crypto';
import express, { Request, Response } from 'express';
import nodemailer from 'nodemailer';
import { v4 as uuidv4 } from 'uuid';
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
const PASSWORD_RESET_COLLECTION = 'passwordResetCodes';
const PASSWORD_RESET_CODE_DIGITS = 4;
const PASSWORD_RESET_EXPIRES_MINUTES = 10;
const PASSWORD_RESET_MAX_ATTEMPTS = 5;
const PASSWORD_RESET_SPECIAL_REGEX = /[!@#\$%^&*(),.?":{}|<>_\-]/;

interface RegisterRequest {
  email: string;
  password: string;
  nomeCompleto: string;
  cpf: string;
  telefone: string;
}

interface ForgotPasswordRequest {
  email: string;
}

interface VerifyPasswordResetCodeRequest {
  email: string;
  resetId: string;
  code: string;
}

interface ConfirmPasswordResetRequest {
  email: string;
  resetId: string;
  resetToken: string;
  newPassword: string;
}

interface FirebasePasswordAuthResponse {
  idToken: string;
  refreshToken: string;
  expiresIn: string;
  localId: string;
  email: string;
}

interface PasswordResetRecord {
  uid?: string;
  email?: string;
  codeHash?: string;
  resetTokenHash?: string;
  attempts?: number;
  consumed?: boolean;
  verified?: boolean;
  expiresAt?: unknown;
}

interface PasswordResetEmailResult {
  devCode?: string;
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

function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

function passwordValidationError(password: string): string | null {
  if (password.length < 6) {
    return 'A senha deve ter pelo menos 6 caracteres';
  }

  if (!/[A-Z]/.test(password)) {
    return 'A senha deve conter pelo menos uma letra maiuscula';
  }

  if (!/[0-9]/.test(password)) {
    return 'A senha deve conter pelo menos um numero';
  }

  if (!PASSWORD_RESET_SPECIAL_REGEX.test(password)) {
    return 'A senha deve conter pelo menos um caractere especial';
  }

  return null;
}

function generatePasswordResetCode(): string {
  const max = 10 ** PASSWORD_RESET_CODE_DIGITS;
  return crypto.randomInt(0, max).toString().padStart(PASSWORD_RESET_CODE_DIGITS, '0');
}

function hashResetValue(value: string, resetId: string): string {
  return crypto.createHash('sha256').update(`${resetId}:${value}`).digest('hex');
}

function passwordResetExpiresAt(): Date {
  return new Date(Date.now() + PASSWORD_RESET_EXPIRES_MINUTES * 60 * 1000);
}

function dateFromFirestoreValue(value: unknown): Date | null {
  if (value instanceof Date) {
    return value;
  }

  if (typeof value === 'object' && value !== null && 'toDate' in value) {
    const timestampLike = value as { toDate?: () => Date };
    if (typeof timestampLike.toDate === 'function') {
      return timestampLike.toDate();
    }
  }

  return null;
}

function assertPasswordResetRecordCanBeUsed(
  data: PasswordResetRecord | undefined,
  email: string
): PasswordResetRecord {
  if (!data || data.email !== email || !data.uid) {
    throw new AppError(400, 'Codigo de recuperacao invalido');
  }

  if (data.consumed) {
    throw new AppError(400, 'Este codigo ja foi utilizado');
  }

  const expiresAt = dateFromFirestoreValue(data.expiresAt);
  if (!expiresAt || expiresAt.getTime() < Date.now()) {
    throw new AppError(400, 'Codigo expirado. Solicite um novo codigo');
  }

  return data;
}

async function sendPasswordResetCodeEmail(
  email: string,
  code: string
): Promise<PasswordResetEmailResult> {
  const host = process.env.SMTP_HOST;
  const from = process.env.SMTP_FROM || process.env.SMTP_USER;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const parsedPort = Number.parseInt(process.env.SMTP_PORT || '587', 10);
  const port = Number.isNaN(parsedPort) ? 587 : parsedPort;
  const secure = process.env.SMTP_SECURE === 'true';

  if (!host || !from) {
    const allowDevCode = process.env.PASSWORD_RESET_DEV_CODE === 'true';

    if (allowDevCode) {
      console.log(`[DEV] Codigo de recuperacao para ${email}: ${code}`);
      return { devCode: code };
    }

    throw new AppError(500, 'Envio de e-mail nao configurado');
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure,
    auth: user && pass ? { user, pass } : undefined,
  });

  await transporter.sendMail({
    from,
    to: email,
    subject: 'Codigo de recuperacao MesclaInvest',
    text: `Seu codigo de recuperacao MesclaInvest e ${code}. Ele expira em ${PASSWORD_RESET_EXPIRES_MINUTES} minutos.`,
    html: `
      <div style="font-family: Arial, sans-serif; line-height: 1.5;">
        <h2>Recuperacao de senha MesclaInvest</h2>
        <p>Use o codigo abaixo no aplicativo para redefinir sua senha:</p>
        <p style="font-size: 28px; font-weight: 700; letter-spacing: 6px;">${code}</p>
        <p>Este codigo expira em ${PASSWORD_RESET_EXPIRES_MINUTES} minutos.</p>
      </div>
    `,
  });

  return {};
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

    const passwordError = passwordValidationError(password);
    if (passwordError) {
      throw new AppError(400, passwordError);
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
    const { email: rawEmail } = req.body as ForgotPasswordRequest;

    if (!rawEmail) {
      throw new AppError(400, 'E-mail e obrigatorio');
    }

    const email = normalizeEmail(rawEmail);

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail invalido');
    }

    let uid: string;
    try {
      const userRecord = await auth().getUserByEmail(email);
      uid = userRecord.uid;
    } catch (error: any) {
      if (error.code === 'auth/user-not-found') {
        throw new AppError(404, 'Usuario com este e-mail nao encontrado');
      }
      throw error;
    }

    const code = generatePasswordResetCode();
    const resetId = uuidv4();
    const firebaseDb = db();
    const resetDocRef = firebaseDb.collection(PASSWORD_RESET_COLLECTION).doc(resetId);

    await resetDocRef.set({
      uid,
      email,
      codeHash: hashResetValue(code, resetId),
      attempts: 0,
      consumed: false,
      verified: false,
      createdAt: FieldValue.serverTimestamp(),
      expiresAt: passwordResetExpiresAt(),
    });

    let emailResult: PasswordResetEmailResult;
    try {
      emailResult = await sendPasswordResetCodeEmail(email, code);
    } catch (error) {
      await resetDocRef.delete().catch(() => undefined);
      throw error;
    }

    res.json({
      message: emailResult.devCode
        ? 'Codigo de recuperacao gerado para desenvolvimento'
        : 'O codigo de recuperacao de senha foi enviado para o seu e-mail',
      email,
      resetId,
      ...(emailResult.devCode ? { devCode: emailResult.devCode } : {}),
    });
  } catch (error) {
    next(error);
  }
});

router.post('/password-reset/verify-code', async (req: Request, res: Response, next: any) => {
  try {
    const { email: rawEmail, resetId, code: rawCode } =
      req.body as VerifyPasswordResetCodeRequest;

    if (!rawEmail || !resetId || !rawCode) {
      throw new AppError(400, 'E-mail, sessao e codigo sao obrigatorios');
    }

    const email = normalizeEmail(rawEmail);
    const code = rawCode.trim();

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail invalido');
    }

    if (!new RegExp(`^\\d{${PASSWORD_RESET_CODE_DIGITS}}$`).test(code)) {
      throw new AppError(400, 'Codigo de recuperacao invalido');
    }

    const resetDocRef = db().collection(PASSWORD_RESET_COLLECTION).doc(resetId);
    const resetDoc = await resetDocRef.get();
    const resetData = assertPasswordResetRecordCanBeUsed(
      resetDoc.data() as PasswordResetRecord | undefined,
      email
    );

    const attempts = resetData.attempts ?? 0;
    if (attempts >= PASSWORD_RESET_MAX_ATTEMPTS) {
      throw new AppError(429, 'Muitas tentativas. Solicite um novo codigo');
    }

    if (resetData.codeHash !== hashResetValue(code, resetId)) {
      await resetDocRef.update({
        attempts: FieldValue.increment(1),
        lastAttemptAt: FieldValue.serverTimestamp(),
      });
      throw new AppError(400, 'Codigo de recuperacao invalido');
    }

    const resetToken = uuidv4();

    await resetDocRef.update({
      verified: true,
      resetTokenHash: hashResetValue(resetToken, resetId),
      verifiedAt: FieldValue.serverTimestamp(),
    });

    res.json({
      message: 'Codigo verificado com sucesso',
      resetToken,
    });
  } catch (error) {
    next(error);
  }
});

router.post('/password-reset/confirm', async (req: Request, res: Response, next: any) => {
  try {
    const { email: rawEmail, resetId, resetToken, newPassword } =
      req.body as ConfirmPasswordResetRequest;

    if (!rawEmail || !resetId || !resetToken || !newPassword) {
      throw new AppError(400, 'Dados obrigatorios ausentes');
    }

    const email = normalizeEmail(rawEmail);

    if (!isValidEmail(email)) {
      throw new AppError(400, 'Formato de e-mail invalido');
    }

    const passwordError = passwordValidationError(newPassword);
    if (passwordError) {
      throw new AppError(400, passwordError);
    }

    const firebaseDb = db();
    const resetDocRef = firebaseDb.collection(PASSWORD_RESET_COLLECTION).doc(resetId);
    const resetDoc = await resetDocRef.get();
    const resetData = assertPasswordResetRecordCanBeUsed(
      resetDoc.data() as PasswordResetRecord | undefined,
      email
    );

    if (
      !resetData.verified ||
      !resetData.resetTokenHash ||
      resetData.resetTokenHash !== hashResetValue(resetToken, resetId)
    ) {
      throw new AppError(400, 'Confirmacao de codigo invalida');
    }

    await auth().updateUser(resetData.uid!, { password: newPassword });
    await auth().revokeRefreshTokens(resetData.uid!).catch(() => undefined);

    await resetDocRef.update({
      consumed: true,
      consumedAt: FieldValue.serverTimestamp(),
    });

    await firebaseDb
      .collection('users')
      .doc(resetData.uid!)
      .update({ updatedAt: FieldValue.serverTimestamp() })
      .catch(() => undefined);

    res.json({
      message: 'Senha redefinida com sucesso',
    });
  } catch (error) {
    next(error);
  }
});

export default router;
