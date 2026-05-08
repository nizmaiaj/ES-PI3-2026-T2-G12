import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

const router = express.Router();

router.get('/', async (req: Request, res: Response, next: any) => {
  try {
    const { estagio } = req.query;
    const firebaseDb = db();

    let query: any = firebaseDb.collection('startups');

    if (estagio) {
      query = query.where('estagio', '==', estagio);
    }

    const snapshot = await query.get();
    const startups = snapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(startups);
  } catch (error) {
    next(error);
  }
});

router.get('/:id', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();

    const startupDoc = await firebaseDb.collection('startups').doc(id).get();

    if (!startupDoc.exists) {
      throw new AppError(404, 'Startup nao encontrada');
    }

    res.json({
      id: startupDoc.id,
      ...startupDoc.data(),
    });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/questions', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();
    const authReq = req as AuthRequest;

    const userTokensSnapshot = await firebaseDb
      .collection('tokenHoldings')
      .doc(`${authReq.uid}_${id}`)
      .get();

    const userHasTokens =
      userTokensSnapshot.exists &&
      (userTokensSnapshot.data()?.quantidade || 0) > 0;

    const questionsSnapshot = await firebaseDb
      .collection('startups')
      .doc(id)
      .collection('questions')
      .orderBy('createdAt', 'desc')
      .get();

    const questions = questionsSnapshot.docs
      .map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      }))
      .filter((q: any) => !q.isPrivada || userHasTokens);

    res.json(questions);
  } catch (error) {
    next(error);
  }
});

router.post('/:id/questions', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const { texto } = req.body;
    const authReq = req as AuthRequest;

    if (!texto) {
      throw new AppError(400, 'O texto da pergunta e obrigatorio');
    }

    const firebaseDb = db();

    const userDoc = await firebaseDb.collection('users').doc(authReq.uid).get();
    const nomeUsuario = userDoc.data()?.nomeCompleto || 'Usuário';

    const questionDocRef = firebaseDb
      .collection('startups')
      .doc(id)
      .collection('questions')
      .doc();

    await questionDocRef.set({
      id: questionDocRef.id,
      startupId: id,
      userId: authReq.uid,
      nomeUsuario,
      texto,
      resposta: null,
      respondidaEm: null,
      isPrivada: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    res.status(201).json({
      id: questionDocRef.id,
      message: 'Pergunta criada com sucesso',
    });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/updates', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();

    const updatesSnapshot = await firebaseDb
      .collection('startups')
      .doc(id)
      .collection('updates')
      .orderBy('createdAt', 'desc')
      .get();

    const updates = updatesSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(updates);
  } catch (error) {
    next(error);
  }
});

router.get('/:id/orders', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();

    const ordersSnapshot = await firebaseDb
      .collection('orders')
      .where('startupId', '==', id)
      .where('status', 'in', ['aberta', 'parcial'])
      .get();

    const orders = ordersSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(orders);
  } catch (error) {
    next(error);
  }
});

router.get('/:id/prices/current', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();

    const latestPriceSnapshot = await firebaseDb
      .collection('tokenPrices')
      .where('startupId', '==', id)
      .orderBy('timestamp', 'desc')
      .limit(1)
      .get();

    if (latestPriceSnapshot.empty) {
      throw new AppError(404, 'Nao ha dados de preco disponiveis');
    }

    const priceData = latestPriceSnapshot.docs[0].data();

    res.json({
      preco: priceData.preco,
      timestamp: priceData.timestamp,
      volume: priceData.volume,
    });
  } catch (error) {
    next(error);
  }
});

router.get('/:id/prices', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const { periodo } = req.query;

    if (periodo !== 'diario') {
      throw new AppError(400, 'O parametro periodo deve ser "diario"');
    }

    const firebaseDb = db();

    const pricesSnapshot = await firebaseDb
      .collection('tokenPrices')
      .where('startupId', '==', id)
      .orderBy('timestamp', 'asc')
      .get();

    const prices = pricesSnapshot.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json(prices);
  } catch (error) {
    next(error);
  }
});

export default router;
