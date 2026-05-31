import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';
import {
  isValidCPF,
  isValidEmail,
  isValidPhoneNumber,
  sanitizeCPF,
  sanitizePhoneNumber,
} from '../utils/validation';

const router = express.Router();

router.get('/me', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;
    const userDoc = await firebaseDb.collection('users').doc(authReq.uid).get();

    if (!userDoc.exists) {
      throw new AppError(404, 'Usuário não encontrado');
    }

    res.json(userDoc.data());
  } catch (error) {
    next(error);
  }
});

router.post('/initialize-profile', async (req: Request, res: Response, next: any) => {
  try {
    const authReq = req as AuthRequest;
    const { nomeCompleto, email, cpf, telefone } = req.body;

    if (!nomeCompleto || !email || !cpf || !telefone) {
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

    const firebaseDb = db();
    const userRef = firebaseDb.collection('users').doc(authReq.uid);
    const walletRef = firebaseDb.collection('wallets').doc(authReq.uid);
    const walletDoc = await walletRef.get();
    const batch = firebaseDb.batch();
    const now = FieldValue.serverTimestamp();

    batch.set(
      userRef,
      {
        uid: authReq.uid,
        nomeCompleto,
        email,
        cpf: sanitizeCPF(cpf),
        telefone: sanitizePhoneNumber(telefone),
        mfaHabilitado: false,
        mfaSecret: null,
        createdAt: now,
        updatedAt: now,
      },
      { merge: true }
    );

    if (!walletDoc.exists) {
      batch.set(walletRef, {
        userId: authReq.uid,
        saldoReais: 0.0,
        updatedAt: now,
      });
    }

    await batch.commit();
    res.status(201).json({ message: 'Perfil inicializado com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.patch('/mfa', async (req: Request, res: Response, next: any) => {
  try {
    const authReq = req as AuthRequest;
    const { habilitado, telefone } = req.body;

    if (typeof habilitado !== 'boolean') {
      throw new AppError(400, 'habilitado deve ser um booleano');
    }

    if (habilitado && (typeof telefone !== 'string' || telefone.trim().length === 0)) {
      throw new AppError(400, 'Telefone obrigatório para habilitar MFA');
    }

    await db()
      .collection('users')
      .doc(authReq.uid)
      .set(
        {
          mfaHabilitado: habilitado,
          mfaTelefone: habilitado ? telefone.trim() : FieldValue.delete(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    res.json({ message: 'Metadados de MFA atualizados com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.patch('/notifications-viewed', async (req: Request, res: Response, next: any) => {
  try {
    const authReq = req as AuthRequest;
    const { viewedAt } = req.body;
    const date = typeof viewedAt === 'string' ? new Date(viewedAt) : null;

    if (!date || Number.isNaN(date.getTime())) {
      throw new AppError(400, 'Data de visualização inválida');
    }

    await db().collection('users').doc(authReq.uid).set(
      {
        notificacoesVistasEm: date,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    res.json({ message: 'Notificações marcadas como visualizadas' });
  } catch (error) {
    next(error);
  }
});

export default router;
