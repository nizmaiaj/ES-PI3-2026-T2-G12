import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

const router = express.Router();

type PricePeriod = 'diario' | 'semanal' | 'mensal' | 'seis_meses' | 'ytd';

interface TransactionPricePoint {
  id: string;
  startupId: string;
  preco: number;
  volume: number;
  timestamp: Date;
}

function parseDate(value: unknown): Date | null {
  if (value instanceof Date) return value;

  if (
    value &&
    typeof value === 'object' &&
    'toDate' in value &&
    typeof value.toDate === 'function'
  ) {
    return value.toDate();
  }

  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ? null : date;
  }

  return null;
}

function parseNumber(value: unknown): number {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const text = value.replace('R$', '').replace(/\s/g, '');
    const normalized = text.includes(',')
      ? text.replace(/\./g, '').replace(',', '.')
      : text;

    return Number(normalized);
  }

  return Number.NaN;
}

async function userHasStartupTokens(
  firebaseDb: FirebaseFirestore.Firestore,
  userId: string,
  startupId: string
): Promise<boolean> {
  const holdingsSnapshot = await firebaseDb
    .collection('tokenHoldings')
    .where('userId', '==', userId)
    .get();

  return holdingsSnapshot.docs.some((doc) => {
    const data = doc.data();
    return data.startupId === startupId && parseNumber(data.quantidade) > 0;
  });
}

function normalizePricePeriod(periodo: unknown): PricePeriod {
  const normalized = typeof periodo === 'string' ? periodo.toLowerCase() : 'mensal';

  if (normalized === 'diario') return 'diario';
  if (normalized === 'semanal') return 'semanal';
  if (normalized === 'mensal') return 'mensal';
  if (
    normalized === '6m' ||
    normalized === 'seis_meses' ||
    normalized === 'ultimos_6_meses' ||
    normalized === 'últimos_6_meses'
  ) {
    return 'seis_meses';
  }
  if (normalized === 'ytd') return 'ytd';

  throw new AppError(
    400,
    'O parâmetro período deve ser um dos valores: diario, semanal, mensal, seis_meses ou ytd'
  );
}

function getPeriodStart(period: PricePeriod, now = new Date()): Date {
  const start = new Date(now);

  if (period === 'diario') {
    start.setDate(start.getDate() - 1);
    return start;
  }

  if (period === 'semanal') {
    start.setDate(start.getDate() - 7);
    return start;
  }

  if (period === 'mensal') {
    start.setDate(start.getDate() - 30);
    return start;
  }

  if (period === 'seis_meses') {
    start.setMonth(start.getMonth() - 6);
    return start;
  }

  return new Date(now.getFullYear(), 0, 1);
}

async function getTransactionPricePoints(
  firebaseDb: FirebaseFirestore.Firestore,
  startupId: string
): Promise<TransactionPricePoint[]> {
  const snapshot = await firebaseDb
    .collection('transactions')
    .where('startupId', '==', startupId)
    .get();

  return snapshot.docs
    .map((doc: any) => {
      const data = doc.data();
      const timestamp = parseDate(
        data.executadaEm ?? data.timestamp ?? data.createdAt ?? data.data
      );
      const preco = parseNumber(
        data.precoUnitario ?? data.preco ?? data.valorToken ?? data.tokenPrice
      );
      const volume = parseNumber(data.quantidade ?? data.volume);

      if (!timestamp || !Number.isFinite(preco) || preco <= 0) {
        return null;
      }

      return {
        id: doc.id,
        startupId,
        preco,
        volume: Number.isFinite(volume) && volume > 0 ? volume : 0,
        timestamp,
      };
    })
    .filter((point): point is TransactionPricePoint => point !== null)
    .sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
}

function filterPricePointsByPeriod(
  points: TransactionPricePoint[],
  period: PricePeriod
): TransactionPricePoint[] {
  if (points.length === 0) return points;

  const start = getPeriodStart(period);

  if (points.length === 1) {
    return points[0].timestamp < start ? [] : points;
  }

  const filtered = points.filter((point) => point.timestamp >= start);
  const previousPoints = points.filter((point) => point.timestamp < start);
  const previous = previousPoints[previousPoints.length - 1];

  if (!previous || filtered.length === 0) return filtered;

  return [
    {
      ...previous,
      id: `${previous.id}_abertura_${period}`,
      timestamp: start,
      volume: 0,
    },
    ...filtered,
  ];
}

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
      throw new AppError(404, 'Startup não encontrada');
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
      .filter((q: any) => !q.isPrivada || q.userId === authReq.uid);

    res.json(questions);
  } catch (error) {
    next(error);
  }
});

router.post('/:id/questions', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const { texto, isPrivada = false } = req.body;
    const authReq = req as AuthRequest;

    if (typeof texto !== 'string' || texto.trim().length === 0) {
      throw new AppError(400, 'O texto da pergunta é obrigatório');
    }

    if (typeof isPrivada !== 'boolean') {
      throw new AppError(400, 'isPrivada deve ser um booleano');
    }

    const firebaseDb = db();

    if (isPrivada && !(await userHasStartupTokens(firebaseDb, authReq.uid, id))) {
      throw new AppError(
        403,
        'Você precisa possuir tokens desta startup para enviar perguntas privadas'
      );
    }

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
      texto: texto.trim(),
      resposta: null,
      respondidaEm: null,
      isPrivada,
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

router.post(
  '/:id/ensure-buy-offers',
  async (req: Request, res: Response, next: any) => {
    try {
      const { id } = req.params;
      const firebaseDb = db();
      const existingOrders = await firebaseDb
        .collection('orders')
        .where('startupId', '==', id)
        .get();

      const alreadyExists = existingOrders.docs.some(
        (doc) => doc.data().tipo === 'ofertacompra'
      );

      if (alreadyExists) {
        res.json({ created: false });
        return;
      }

      const startupDoc = await firebaseDb.collection('startups').doc(id).get();

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      const startup = startupDoc.data() || {};
      const currentPrice = parseNumber(
        startup.valorToken ??
          startup.tokenPrecoInicial
      );

      if (!Number.isFinite(currentPrice) || currentPrice <= 0) {
        throw new AppError(400, 'Startup sem preço de token válido');
      }

      const offers = [
        { factor: 0.885, quantity: 100 },
        { factor: 0.91, quantity: 50 },
        { factor: 0.93, quantity: 200 },
        { factor: 0.95, quantity: 75 },
        { factor: 0.97, quantity: 30 },
      ];
      const batch = firebaseDb.batch();
      const now = FieldValue.serverTimestamp();

      offers.forEach(({ factor, quantity }, index) => {
        const ref = firebaseDb.collection('orders').doc(`system_buy_offer_${id}_${index}`);
        const price = Math.round(currentPrice * factor * 100) / 100;

        batch.set(ref, {
          id: ref.id,
          tipo: 'ofertacompra',
          startupId: id,
          preco: price,
          precoUnitario: price,
          quantidade: quantity,
          quantidadeRestante: quantity,
          quantidadeExecutada: 0,
          status: 'aberta',
          createdAt: now,
          updatedAt: now,
        });
      });

      await batch.commit();
      res.status(201).json({ created: true });
    } catch (error) {
      next(error);
    }
  }
);

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

router.get(
  '/:id/prices/current',
  async (req: Request, res: Response, next: any) => {
    try {
      const { id } = req.params;
      const firebaseDb = db();
      const prices = await getTransactionPricePoints(firebaseDb, id);
      const latestPrice = prices[prices.length - 1];

      if (!latestPrice) {
        throw new AppError(404, 'Não há transações de preço disponíveis');
      }

      res.json({
        preco: latestPrice.preco,
        timestamp: latestPrice.timestamp,
        volume: latestPrice.volume,
      });
    } catch (error) {
      next(error);
    }
  }
);

router.get('/:id/prices', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const { periodo } = req.query;
    const pricePeriod = normalizePricePeriod(periodo);

    const firebaseDb = db();
    const prices = filterPricePointsByPeriod(
      await getTransactionPricePoints(firebaseDb, id),
      pricePeriod
    );

    res.json(
      prices.map((price) => ({
        id: price.id,
        startupId: price.startupId,
        preco: price.preco,
        precoUnitario: price.preco,
        volume: price.volume,
        quantidade: price.volume,
        timestamp: price.timestamp,
        executadaEm: price.timestamp,
      }))
    );
  } catch (error) {
    next(error);
  }
});

export default router;
