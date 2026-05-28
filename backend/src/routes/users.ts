import express, { Request, Response } from 'express';
import { db } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

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

export default router;
