import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

const router = express.Router();

router.get('/', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;
    const walletDoc = await firebaseDb.collection('wallets').doc(authReq.uid).get();

    if (!walletDoc.exists) {
      throw new AppError(404, 'Carteira não encontrada');
    }

    res.json(walletDoc.data());
  } catch (error) {
    next(error);
  }
});

router.post('/credit', async (req: Request, res: Response, next: any) => {
  try {
    const { valor } = req.body;
    const authReq = req as AuthRequest;

    if (typeof valor !== 'number' || valor <= 0) {
      throw new AppError(400, 'Valor deve ser um número positivo');
    }

    const firebaseDb = db();

    const result = await firebaseDb.runTransaction(async (transaction) => {
      const walletRef = firebaseDb.collection('wallets').doc(authReq.uid);
      const walletDoc = await transaction.get(walletRef);

      if (!walletDoc.exists) {
        throw new AppError(404, 'Carteira não encontrada');
      }

      const currentBalance = walletDoc.data()?.saldoReais || 0;
      const newBalance = currentBalance + valor;

      transaction.update(walletRef, {
        saldoReais: newBalance,
        updatedAt: FieldValue.serverTimestamp(),
      });

      const creditDocRef = firebaseDb.collection('walletCredits').doc();
      transaction.set(creditDocRef, {
        userId: authReq.uid,
        valor,
        tipo: 'deposito',
        descricao: 'Crédito fictício adicionado à carteira',
        createdAt: FieldValue.serverTimestamp(),
      });

      return {
        saldoAnterior: currentBalance,
        saldoNovo: newBalance,
        valor,
      };
    });

    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/history', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;
    const creditsSnapshot = await firebaseDb
      .collection('walletCredits')
      .where('userId', '==', authReq.uid)
      .orderBy('createdAt', 'desc')
      .get();

    const credits = creditsSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(credits);
  } catch (error) {
    next(error);
  }
});

export default router;
