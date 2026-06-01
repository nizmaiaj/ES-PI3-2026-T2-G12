// Consolida compras e vendas do usuário em um único histórico cronológico.
import express, { Request, Response } from 'express';
import { db } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';

const router = express.Router();

// O Firestore consulta comprador e vendedor separadamente; a API une os dois
// resultados para entregar um extrato completo ao aplicativo.
router.get('/', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;

    const transactionsSnapshot = await firebaseDb
      .collection('transactions')
      .where('buyerId', '==', authReq.uid)
      .orderBy('executadaEm', 'desc')
      .get();

    const buyerTransactions = transactionsSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    const sellerTransactionsSnapshot = await firebaseDb
      .collection('transactions')
      .where('sellerId', '==', authReq.uid)
      .orderBy('executadaEm', 'desc')
      .get();

    const sellerTransactions = sellerTransactionsSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    const allTransactions = [
      ...buyerTransactions,
      ...sellerTransactions,
    ].sort(
      (a: any, b: any) =>
        b.executadaEm.toMillis() - a.executadaEm.toMillis()
    );

    res.json(allTransactions);
  } catch (error) {
    next(error);
  }
});

export default router;
