// Consulta as posições de tokens mantidas pelo usuário autenticado.
import express, { Request, Response } from 'express';
import { db } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

const router = express.Router();

// Lista todas as posições, incluindo preço médio de aquisição.
router.get('/', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;

    const holdingsSnapshot = await firebaseDb
      .collection('tokenHoldings')
      .where('userId', '==', authReq.uid)
      .get();

    const holdings = holdingsSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(holdings);
  } catch (error) {
    next(error);
  }
});

// Retorna uma posição específica ou um objeto zerado para simplificar a UI.
router.get('/:startupId', async (req: Request, res: Response, next: any) => {
  try {
    const { startupId } = req.params;
    const firebaseDb = db();
    const authReq = req as AuthRequest;

    const holdingDocId = `${authReq.uid}_${startupId}`;
    const holdingDoc = await firebaseDb
      .collection('tokenHoldings')
      .doc(holdingDocId)
      .get();

    if (!holdingDoc.exists) {
      res.json({
        quantidade: 0,
        precoMedioCompra: 0,
        updatedAt: null,
      });
      return;
    }

    res.json({
      id: holdingDoc.id,
      ...holdingDoc.data(),
    });
  } catch (error) {
    next(error);
  }
});

export default router;
