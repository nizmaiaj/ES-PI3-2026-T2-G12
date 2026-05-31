import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';
import { initializeUserProfile } from '../services/userProfileService';
import {
  isValidCPF,
  isValidEmail,
  isValidPhoneNumber,
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

    await initializeUserProfile({
      uid: authReq.uid,
      nomeCompleto,
      email,
      cpf,
      telefone,
    });
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
