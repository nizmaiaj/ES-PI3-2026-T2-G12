import express, { Request, Response } from 'express';
import { db, FieldValue } from '../config/firebase';
import { AuthRequest } from '../middleware/auth';
import { AppError } from '../middleware/errorHandler';

const router = express.Router();

type OrderType = 'compra' | 'venda';
type OrderStatus = 'aberta' | 'parcial' | 'executada' | 'cancelada';

interface OrderData {
  id: string;
  userId: string;
  startupId: string;
  tipo: OrderType;
  quantidade: number;
  quantidadeExecutada: number;
  preco: number;
  status: OrderStatus;
  createdAt: FirebaseFirestore.FieldValue;
  updatedAt: FirebaseFirestore.FieldValue;
}

interface MatchData {
  buyOrderId: string;
  sellOrderId: string;
  buyerId: string;
  sellerId: string;
  quantidade: number;
  precoUnitario: number;
  buyerOrderRef: FirebaseFirestore.DocumentReference;
  sellerOrderRef: FirebaseFirestore.DocumentReference;
  buyerOrderExecuted: number;
  sellerOrderExecuted: number;
  buyerOrderTotal: number;
  sellerOrderTotal: number;
}

interface HoldingData {
  quantidade: number;
  precoMedioCompra: number;
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

  return 0;
}

function assertWithinIssuedTokenLimit(
  startup: FirebaseFirestore.DocumentData,
  quantidade: number
): void {
  const tokensEmitidos = parseNumber(
    startup.totalTokens ??
      startup.tokensEmitidos ??
      startup.tokensDisponiveis ??
      startup.quantidadeTokens ??
      startup.tokens
  );

  if (!Number.isFinite(tokensEmitidos) || tokensEmitidos < 0) {
    throw new AppError(400, 'Startup sem quantidade de tokens emitidos válida');
  }

  if (quantidade > tokensEmitidos) {
    throw new AppError(
      400,
      `A quantidade desejada é maior que os ${tokensEmitidos} tokens emitidos pela startup`
    );
  }
}

function remainingQuantity(order: FirebaseFirestore.DocumentData): number {
  const explicitRemaining = parseNumber(order.quantidadeRestante);
  if (explicitRemaining > 0) return explicitRemaining;

  return Math.max(0, parseNumber(order.quantidade) - parseNumber(order.quantidadeExecutada));
}

function isOpenStatus(status: unknown): boolean {
  return status === 'aberta' || status === 'parcial' || status === 'pendente';
}

async function getHoldingRefs(
  firebaseDb: FirebaseFirestore.Firestore,
  userId: string,
  startupId: string
): Promise<FirebaseFirestore.DocumentReference[]> {
  const canonicalRef = firebaseDb.collection('tokenHoldings').doc(`${userId}_${startupId}`);
  const holdingsSnapshot = await firebaseDb
    .collection('tokenHoldings')
    .where('userId', '==', userId)
    .get();
  const legacyRefs = holdingsSnapshot.docs
    .filter((doc) => doc.data().startupId === startupId)
    .map((doc) => doc.ref)
    .filter((ref) => ref.path !== canonicalRef.path);

  return [canonicalRef, ...legacyRefs];
}

async function readHolding(
  transaction: FirebaseFirestore.Transaction,
  refs: FirebaseFirestore.DocumentReference[]
): Promise<HoldingData> {
  const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
  let quantidade = 0;
  let totalCost = 0;

  snapshots.forEach((snapshot) => {
    const data = snapshot.data();
    if (!data) return;

    const itemQuantity = parseNumber(data.quantidade);
    quantidade += itemQuantity;
    totalCost += itemQuantity * parseNumber(data.precoMedioCompra);
  });

  return {
    quantidade,
    precoMedioCompra: quantidade > 0 ? totalCost / quantidade : 0,
  };
}

function writeHolding(
  transaction: FirebaseFirestore.Transaction,
  refs: FirebaseFirestore.DocumentReference[],
  userId: string,
  startupId: string,
  holding: HoldingData,
  now: FirebaseFirestore.FieldValue
): void {
  const [canonicalRef, ...legacyRefs] = refs;

  transaction.set(
    canonicalRef,
    {
      userId,
      startupId,
      quantidade: holding.quantidade,
      precoMedioCompra: holding.precoMedioCompra,
      updatedAt: now,
    },
    { merge: true }
  );

  legacyRefs.forEach((ref) => transaction.delete(ref));
}

function createTransactionRecords({
  buyerId,
  buyOrderId,
  firebaseDb,
  now,
  preco,
  quantidade,
  sellerId,
  sellOrderId,
  startupId,
  transaction,
}: {
  buyerId: string;
  buyOrderId: string;
  firebaseDb: FirebaseFirestore.Firestore;
  now: FirebaseFirestore.FieldValue;
  preco: number;
  quantidade: number;
  sellerId?: string;
  sellOrderId?: string;
  startupId: string;
  transaction: FirebaseFirestore.Transaction;
}): void {
  const total = preco * quantidade;
  const transactionRef = firebaseDb.collection('transactions').doc();
  const tokenPriceRef = firebaseDb.collection('tokenPrices').doc();
  const buyerCreditRef = firebaseDb.collection('walletCredits').doc();

  transaction.set(transactionRef, {
    id: transactionRef.id,
    startupId,
    buyerId,
    ...(sellerId ? { sellerId } : {}),
    quantidade,
    precoUnitario: preco,
    valorTotal: total,
    orderCompraId: buyOrderId,
    ...(sellOrderId ? { orderVendaId: sellOrderId } : {}),
    executadaEm: now,
  });

  transaction.set(tokenPriceRef, {
    id: tokenPriceRef.id,
    startupId,
    preco,
    volume: quantidade,
    timestamp: now,
  });

  transaction.set(buyerCreditRef, {
    userId: buyerId,
    valor: -total,
    tipo: 'compra',
    descricao: `Compra de ${quantidade} tokens`,
    createdAt: now,
  });

  if (sellerId) {
    const sellerCreditRef = firebaseDb.collection('walletCredits').doc();
    transaction.set(sellerCreditRef, {
      userId: sellerId,
      valor: total,
      tipo: 'venda',
      descricao: `Venda de ${quantidade} tokens`,
      createdAt: now,
    });
  }
}

function getOrderStatus(executed: number, total: number): OrderStatus {
  if (executed <= 0) return 'aberta';
  if (executed >= total) return 'executada';
  return 'parcial';
}

function assertIntegerTokenValue(value: unknown, fieldName: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    throw new AppError(400, `${fieldName} deve ser um número inteiro positivo`);
  }

  return value;
}

function assertPositiveMoneyValue(value: unknown, fieldName: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    throw new AppError(400, `${fieldName} deve ser um número positivo`);
  }

  return value;
}

router.post('/sell', async (req: Request, res: Response, next: any) => {
  try {
    const { startupId } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const preco = assertPositiveMoneyValue(req.body.preco, 'preco');
    const authReq = req as AuthRequest;

    if (typeof startupId !== 'string' || startupId.trim().length === 0) {
      throw new AppError(400, 'startupId é obrigatório');
    }

    const firebaseDb = db();
    const holdingRefs = await getHoldingRefs(firebaseDb, authReq.uid, startupId);
    const orderRef = firebaseDb.collection('orders').doc();

    await firebaseDb.runTransaction(async (transaction) => {
      const startupDoc = await transaction.get(firebaseDb.collection('startups').doc(startupId));
      const holding = await readHolding(transaction, holdingRefs);

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      if (holding.quantidade < quantidade) {
        throw new AppError(400, 'Tokens insuficientes para venda');
      }

      const now = FieldValue.serverTimestamp();
      writeHolding(
        transaction,
        holdingRefs,
        authReq.uid,
        startupId,
        {
          quantidade: holding.quantidade - quantidade,
          precoMedioCompra: holding.precoMedioCompra,
        },
        now
      );
      transaction.set(orderRef, {
        id: orderRef.id,
        userId: authReq.uid,
        sellerId: authReq.uid,
        startupId,
        tipo: 'venda',
        quantidade,
        quantidadeExecutada: 0,
        quantidadeRestante: quantidade,
        preco,
        precoUnitario: preco,
        status: 'aberta',
        createdAt: now,
        updatedAt: now,
      });
    });

    res.status(201).json({ id: orderRef.id, message: 'Ordem de venda criada com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.post('/buy-sell-order', async (req: Request, res: Response, next: any) => {
  try {
    const { ordemId } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const authReq = req as AuthRequest;

    if (typeof ordemId !== 'string' || ordemId.trim().length === 0) {
      throw new AppError(400, 'ordemId é obrigatório');
    }

    const firebaseDb = db();
    const orderRef = firebaseDb.collection('orders').doc(ordemId);
    const orderSnapshot = await orderRef.get();
    const startupId = orderSnapshot.data()?.startupId;

    if (typeof startupId !== 'string' || startupId.length === 0) {
      throw new AppError(404, 'Oferta não encontrada');
    }

    const buyerHoldingRefs = await getHoldingRefs(firebaseDb, authReq.uid, startupId);

    await firebaseDb.runTransaction(async (transaction) => {
      const orderDoc = await transaction.get(orderRef);
      const startupDoc = await transaction.get(firebaseDb.collection('startups').doc(startupId));

      if (!orderDoc.exists) {
        throw new AppError(404, 'Oferta não encontrada');
      }

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      const order = orderDoc.data() || {};
      const sellerId = String(order.sellerId ?? order.userId ?? '');
      const price = parseNumber(order.preco ?? order.precoUnitario);
      const remaining = remainingQuantity(order);
      const buyerWalletRef = firebaseDb.collection('wallets').doc(authReq.uid);
      const sellerWalletRef = firebaseDb.collection('wallets').doc(sellerId);
      const buyerWalletDoc = await transaction.get(buyerWalletRef);
      const sellerWalletDoc = await transaction.get(sellerWalletRef);
      const buyerHolding = await readHolding(transaction, buyerHoldingRefs);

      if (order.tipo !== 'venda' || !isOpenStatus(order.status)) {
        throw new AppError(400, 'Esta oferta não está mais disponível');
      }

      if (!sellerId || sellerId === authReq.uid || !Number.isFinite(price) || price <= 0) {
        throw new AppError(400, 'Oferta inválida');
      }

      if (remaining < quantidade) {
        throw new AppError(400, 'Quantidade indisponível nesta oferta');
      }

      assertWithinIssuedTokenLimit(startupDoc.data() || {}, quantidade);

      if (!buyerWalletDoc.exists) {
        throw new AppError(404, 'Carteira do comprador não encontrada');
      }

      const total = price * quantidade;
      const buyerBalance = parseNumber(buyerWalletDoc.data()?.saldoReais);
      const sellerBalance = parseNumber(sellerWalletDoc.data()?.saldoReais);

      if (buyerBalance < total) {
        throw new AppError(400, 'Saldo insuficiente na carteira');
      }

      const newQuantity = buyerHolding.quantidade + quantidade;
      const newExecuted = parseNumber(order.quantidadeExecutada) + quantidade;
      const newRemaining = Math.max(0, parseNumber(order.quantidade) - newExecuted);
      const now = FieldValue.serverTimestamp();
      const buyOrderRef = firebaseDb.collection('orders').doc();

      transaction.update(buyerWalletRef, {
        saldoReais: buyerBalance - total,
        updatedAt: now,
      });
      transaction.set(
        sellerWalletRef,
        {
          userId: sellerId,
          saldoReais: sellerBalance + total,
          updatedAt: now,
        },
        { merge: true }
      );
      writeHolding(
        transaction,
        buyerHoldingRefs,
        authReq.uid,
        startupId,
        {
          quantidade: newQuantity,
          precoMedioCompra:
            (buyerHolding.quantidade * buyerHolding.precoMedioCompra + total) / newQuantity,
        },
        now
      );
      transaction.update(orderRef, {
        quantidadeExecutada: newExecuted,
        quantidadeRestante: newRemaining,
        status: newRemaining === 0 ? 'executada' : 'parcial',
        updatedAt: now,
        ...(newRemaining === 0 ? { executadaEm: now } : {}),
      });
      transaction.set(buyOrderRef, {
        id: buyOrderRef.id,
        userId: authReq.uid,
        buyerId: authReq.uid,
        sellerId,
        startupId,
        tipo: 'compra',
        quantidade,
        quantidadeExecutada: quantidade,
        quantidadeRestante: 0,
        preco: price,
        precoUnitario: price,
        status: 'executada',
        orderVendaId: orderRef.id,
        createdAt: now,
        updatedAt: now,
        executadaEm: now,
      });
      createTransactionRecords({
        buyerId: authReq.uid,
        buyOrderId: buyOrderRef.id,
        firebaseDb,
        now,
        preco: price,
        quantidade,
        sellerId,
        sellOrderId: orderRef.id,
        startupId,
        transaction,
      });
    });

    res.status(201).json({ message: 'Compra registrada com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.post('/buy-startup-offer', async (req: Request, res: Response, next: any) => {
  try {
    const { ofertaId } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const authReq = req as AuthRequest;

    if (typeof ofertaId !== 'string' || ofertaId.trim().length === 0) {
      throw new AppError(400, 'ofertaId é obrigatório');
    }

    const firebaseDb = db();
    const offerRef = firebaseDb.collection('orders').doc(ofertaId);
    const offerSnapshot = await offerRef.get();
    const startupId = offerSnapshot.data()?.startupId;

    if (typeof startupId !== 'string' || startupId.length === 0) {
      throw new AppError(404, 'Oferta não encontrada');
    }

    const buyerHoldingRefs = await getHoldingRefs(firebaseDb, authReq.uid, startupId);

    await firebaseDb.runTransaction(async (transaction) => {
      const offerDoc = await transaction.get(offerRef);
      const startupDoc = await transaction.get(firebaseDb.collection('startups').doc(startupId));
      const walletRef = firebaseDb.collection('wallets').doc(authReq.uid);
      const walletDoc = await transaction.get(walletRef);
      const buyerHolding = await readHolding(transaction, buyerHoldingRefs);

      if (!offerDoc.exists) {
        throw new AppError(404, 'Oferta não encontrada');
      }

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      const offer = offerDoc.data() || {};
      const price = parseNumber(offer.preco ?? offer.precoUnitario);
      const remaining = remainingQuantity(offer);

      if (offer.tipo !== 'ofertacompra' || !isOpenStatus(offer.status)) {
        throw new AppError(400, 'Esta oferta não está mais disponível');
      }

      if (!Number.isFinite(price) || price <= 0) {
        throw new AppError(400, 'Oferta com preço inválido');
      }

      if (remaining < quantidade) {
        throw new AppError(400, 'Quantidade indisponível nesta oferta');
      }

      assertWithinIssuedTokenLimit(startupDoc.data() || {}, quantidade);

      if (!walletDoc.exists) {
        throw new AppError(404, 'Carteira não encontrada');
      }

      const balance = parseNumber(walletDoc.data()?.saldoReais);
      const total = price * quantidade;

      if (balance < total) {
        throw new AppError(400, 'Saldo insuficiente na carteira');
      }

      const newQuantity = buyerHolding.quantidade + quantidade;
      const newExecuted = parseNumber(offer.quantidadeExecutada) + quantidade;
      const newRemaining = Math.max(0, parseNumber(offer.quantidade) - newExecuted);
      const now = FieldValue.serverTimestamp();
      const buyOrderRef = firebaseDb.collection('orders').doc();

      transaction.update(offerRef, {
        quantidadeExecutada: newExecuted,
        quantidadeRestante: newRemaining,
        status: newRemaining === 0 ? 'executada' : 'parcial',
        updatedAt: now,
        ...(newRemaining === 0 ? { executadaEm: now } : {}),
      });
      transaction.update(walletRef, { saldoReais: balance - total, updatedAt: now });
      writeHolding(
        transaction,
        buyerHoldingRefs,
        authReq.uid,
        startupId,
        {
          quantidade: newQuantity,
          precoMedioCompra:
            (buyerHolding.quantidade * buyerHolding.precoMedioCompra + total) / newQuantity,
        },
        now
      );
      transaction.set(buyOrderRef, {
        id: buyOrderRef.id,
        userId: authReq.uid,
        buyerId: authReq.uid,
        startupId,
        tipo: 'compra',
        quantidade,
        quantidadeExecutada: quantidade,
        quantidadeRestante: 0,
        preco: price,
        precoUnitario: price,
        status: 'executada',
        ofertaCompraId: offerRef.id,
        createdAt: now,
        updatedAt: now,
        executadaEm: now,
      });
      createTransactionRecords({
        buyerId: authReq.uid,
        buyOrderId: buyOrderRef.id,
        firebaseDb,
        now,
        preco: price,
        quantidade,
        startupId,
        transaction,
      });
    });

    res.status(201).json({ message: 'Compra registrada com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.post('/buy-direct', async (req: Request, res: Response, next: any) => {
  try {
    const { startupId } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const authReq = req as AuthRequest;

    if (typeof startupId !== 'string' || startupId.trim().length === 0) {
      throw new AppError(400, 'startupId é obrigatório');
    }

    const firebaseDb = db();
    const buyerHoldingRefs = await getHoldingRefs(firebaseDb, authReq.uid, startupId);

    await firebaseDb.runTransaction(async (transaction) => {
      const startupDoc = await transaction.get(firebaseDb.collection('startups').doc(startupId));
      const walletRef = firebaseDb.collection('wallets').doc(authReq.uid);
      const walletDoc = await transaction.get(walletRef);
      const buyerHolding = await readHolding(transaction, buyerHoldingRefs);

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      if (!walletDoc.exists) {
        throw new AppError(404, 'Carteira não encontrada');
      }

      const startup = startupDoc.data() || {};
      const price = parseNumber(
        startup.valorToken ?? startup.precoToken ?? startup.tokenPrecoInicial ?? startup.preco
      );

      assertWithinIssuedTokenLimit(startup, quantidade);

      if (!Number.isFinite(price) || price <= 0) {
        throw new AppError(400, 'Startup sem preço de token válido');
      }

      const balance = parseNumber(walletDoc.data()?.saldoReais);
      const total = price * quantidade;

      if (balance < total) {
        throw new AppError(400, 'Saldo insuficiente na carteira');
      }

      const newQuantity = buyerHolding.quantidade + quantidade;
      const now = FieldValue.serverTimestamp();
      const buyOrderRef = firebaseDb.collection('orders').doc();

      transaction.update(walletRef, { saldoReais: balance - total, updatedAt: now });
      writeHolding(
        transaction,
        buyerHoldingRefs,
        authReq.uid,
        startupId,
        {
          quantidade: newQuantity,
          precoMedioCompra:
            (buyerHolding.quantidade * buyerHolding.precoMedioCompra + total) / newQuantity,
        },
        now
      );
      transaction.set(buyOrderRef, {
        id: buyOrderRef.id,
        userId: authReq.uid,
        buyerId: authReq.uid,
        startupId,
        tipo: 'compra',
        quantidade,
        quantidadeExecutada: quantidade,
        quantidadeRestante: 0,
        preco: price,
        precoUnitario: price,
        status: 'executada',
        createdAt: now,
        updatedAt: now,
        executadaEm: now,
      });
      createTransactionRecords({
        buyerId: authReq.uid,
        buyOrderId: buyOrderRef.id,
        firebaseDb,
        now,
        preco: price,
        quantidade,
        startupId,
        transaction,
      });
    });

    res.status(201).json({ message: 'Compra registrada com sucesso' });
  } catch (error) {
    next(error);
  }
});

router.post('/', async (req: Request, res: Response, next: any) => {
  try {
    const { startupId, tipo } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const preco = assertPositiveMoneyValue(req.body.preco, 'preco');
    const authReq = req as AuthRequest;

    if (!startupId || !tipo) {
      throw new AppError(400, 'Campos obrigatórios ausentes');
    }

    if (!['compra', 'venda'].includes(tipo)) {
      throw new AppError(400, 'tipo deve ser "compra" ou "venda"');
    }

    const firebaseDb = db();
    const orderDocRef = firebaseDb.collection('orders').doc();
    const oppositeType: OrderType = tipo === 'compra' ? 'venda' : 'compra';

    const result = await firebaseDb.runTransaction(async (transaction) => {
      const startupRef = firebaseDb.collection('startups').doc(startupId);
      const startupDoc = await transaction.get(startupRef);

      if (!startupDoc.exists) {
        throw new AppError(404, 'Startup não encontrada');
      }

      if (tipo === 'compra') {
        assertWithinIssuedTokenLimit(startupDoc.data() || {}, quantidade);
      }

      if (tipo === 'venda') {
        const sellerHoldingRef = firebaseDb
          .collection('tokenHoldings')
          .doc(`${authReq.uid}_${startupId}`);
        const sellerHoldingDoc = await transaction.get(sellerHoldingRef);
        const sellerQuantity = sellerHoldingDoc.data()?.quantidade || 0;

        if (sellerQuantity < quantidade) {
          throw new AppError(400, 'Tokens insuficientes para criar ordem de venda');
        }
      }

      const oppositeOrdersSnapshot = await transaction.get(
        firebaseDb
          .collection('orders')
          .where('startupId', '==', startupId)
          .where('tipo', '==', oppositeType)
          .where('status', 'in', ['aberta', 'parcial'])
      );

      const oppositeOrders = oppositeOrdersSnapshot.docs
        .map((doc) => ({
          ref: doc.ref,
          data: doc.data() as OrderData,
        }))
        .filter(({ data }) => data.userId !== authReq.uid)
        .filter(({ data }) =>
          tipo === 'compra' ? data.preco <= preco : data.preco >= preco
        )
        .sort((a, b) => {
          if (tipo === 'compra') {
            return a.data.preco - b.data.preco;
          }

          return b.data.preco - a.data.preco;
        });

      let currentOrderExecuted = 0;
      const matches: MatchData[] = [];
      const updatedOppositeExecutions = new Map<string, number>();

      for (const { ref, data } of oppositeOrders) {
        const currentRemaining = quantidade - currentOrderExecuted;
        const oppositeAlreadyExecuted =
          updatedOppositeExecutions.get(data.id) ?? data.quantidadeExecutada;
        const oppositeRemaining = data.quantidade - oppositeAlreadyExecuted;

        if (currentRemaining <= 0) break;
        if (oppositeRemaining <= 0) continue;

        const matchedQuantity = Math.min(currentRemaining, oppositeRemaining);
        const newOppositeExecuted = oppositeAlreadyExecuted + matchedQuantity;
        currentOrderExecuted += matchedQuantity;
        updatedOppositeExecutions.set(data.id, newOppositeExecuted);

        matches.push({
          buyOrderId: tipo === 'compra' ? orderDocRef.id : data.id,
          sellOrderId: tipo === 'venda' ? orderDocRef.id : data.id,
          buyerId: tipo === 'compra' ? authReq.uid : data.userId,
          sellerId: tipo === 'venda' ? authReq.uid : data.userId,
          quantidade: matchedQuantity,
          precoUnitario: data.preco,
          buyerOrderRef: tipo === 'compra' ? orderDocRef : ref,
          sellerOrderRef: tipo === 'venda' ? orderDocRef : ref,
          buyerOrderExecuted:
            tipo === 'compra' ? currentOrderExecuted : newOppositeExecuted,
          sellerOrderExecuted:
            tipo === 'venda' ? currentOrderExecuted : newOppositeExecuted,
          buyerOrderTotal: tipo === 'compra' ? quantidade : data.quantidade,
          sellerOrderTotal: tipo === 'venda' ? quantidade : data.quantidade,
        });
      }

      const walletRefs = new Map<string, FirebaseFirestore.DocumentReference>();
      const holdingRefs = new Map<string, FirebaseFirestore.DocumentReference>();
      const holdingOwners = new Map<string, string>();
      const walletBalances = new Map<string, number>();
      const holdings = new Map<
        string,
        { quantidade: number; precoMedioCompra: number }
      >();

      for (const match of matches) {
        walletRefs.set(match.buyerId, firebaseDb.collection('wallets').doc(match.buyerId));
        walletRefs.set(match.sellerId, firebaseDb.collection('wallets').doc(match.sellerId));
        holdingRefs.set(
          `${match.buyerId}_${startupId}`,
          firebaseDb.collection('tokenHoldings').doc(`${match.buyerId}_${startupId}`)
        );
        holdingOwners.set(`${match.buyerId}_${startupId}`, match.buyerId);
        holdingRefs.set(
          `${match.sellerId}_${startupId}`,
          firebaseDb.collection('tokenHoldings').doc(`${match.sellerId}_${startupId}`)
        );
        holdingOwners.set(`${match.sellerId}_${startupId}`, match.sellerId);
      }

      for (const [userId, ref] of walletRefs) {
        const walletDoc = await transaction.get(ref);

        if (!walletDoc.exists) {
          throw new AppError(404, `Carteira não encontrada para o usuário ${userId}`);
        }

        walletBalances.set(userId, walletDoc.data()?.saldoReais || 0);
      }

      for (const [holdingId, ref] of holdingRefs) {
        const holdingDoc = await transaction.get(ref);
        holdings.set(holdingId, {
          quantidade: holdingDoc.data()?.quantidade || 0,
          precoMedioCompra: holdingDoc.data()?.precoMedioCompra || 0,
        });
      }

      let totalCapitalAportado = 0;

      for (const match of matches) {
        const total = match.quantidade * match.precoUnitario;
        const buyerBalance = walletBalances.get(match.buyerId) || 0;
        const sellerBalance = walletBalances.get(match.sellerId) || 0;
        const buyerHoldingId = `${match.buyerId}_${startupId}`;
        const sellerHoldingId = `${match.sellerId}_${startupId}`;
        const buyerHolding = holdings.get(buyerHoldingId) || {
          quantidade: 0,
          precoMedioCompra: 0,
        };
        const sellerHolding = holdings.get(sellerHoldingId) || {
          quantidade: 0,
          precoMedioCompra: 0,
        };

        if (buyerBalance < total) {
          throw new AppError(400, 'Saldo insuficiente para executar a ordem');
        }

        if (sellerHolding.quantidade < match.quantidade) {
          throw new AppError(400, 'Tokens insuficientes para executar a ordem');
        }

        const newBuyerQuantity = buyerHolding.quantidade + match.quantidade;
        const newBuyerAverage =
          (buyerHolding.quantidade * buyerHolding.precoMedioCompra + total) /
          newBuyerQuantity;

        walletBalances.set(match.buyerId, buyerBalance - total);
        walletBalances.set(match.sellerId, sellerBalance + total);
        holdings.set(buyerHoldingId, {
          quantidade: newBuyerQuantity,
          precoMedioCompra: newBuyerAverage,
        });
        holdings.set(sellerHoldingId, {
          quantidade: sellerHolding.quantidade - match.quantidade,
          precoMedioCompra: sellerHolding.precoMedioCompra,
        });
        totalCapitalAportado += total;
      }

      const now = FieldValue.serverTimestamp();
      const orderData: OrderData = {
        id: orderDocRef.id,
        userId: authReq.uid,
        startupId,
        tipo,
        quantidade,
        quantidadeExecutada: currentOrderExecuted,
        preco,
        status: getOrderStatus(currentOrderExecuted, quantidade),
        createdAt: now,
        updatedAt: now,
      };

      transaction.set(orderDocRef, orderData);

      for (const { ref, data } of oppositeOrders) {
        const newExecuted = updatedOppositeExecutions.get(data.id);
        if (newExecuted === undefined) continue;

        transaction.update(ref, {
          quantidadeExecutada: newExecuted,
          status: getOrderStatus(newExecuted, data.quantidade),
          updatedAt: now,
        });
      }

      for (const [userId, ref] of walletRefs) {
        transaction.update(ref, {
          saldoReais: walletBalances.get(userId) || 0,
          updatedAt: now,
        });
      }

      for (const [holdingId, ref] of holdingRefs) {
        const holding = holdings.get(holdingId);
        if (!holding) continue;

        const userId = holdingOwners.get(holdingId);
        if (!userId) continue;

        transaction.set(
          ref,
          {
            userId,
            startupId,
            quantidade: holding.quantidade,
            precoMedioCompra: holding.precoMedioCompra,
            updatedAt: now,
          },
          { merge: true }
        );
      }

      for (const match of matches) {
        const valorTotal = match.quantidade * match.precoUnitario;
        const transactionRef = firebaseDb.collection('transactions').doc();
        const tokenPriceRef = firebaseDb.collection('tokenPrices').doc();
        const buyerCreditRef = firebaseDb.collection('walletCredits').doc();
        const sellerCreditRef = firebaseDb.collection('walletCredits').doc();

        transaction.set(transactionRef, {
          id: transactionRef.id,
          startupId,
          buyerId: match.buyerId,
          sellerId: match.sellerId,
          quantidade: match.quantidade,
          precoUnitario: match.precoUnitario,
          valorTotal,
          orderCompraId: match.buyOrderId,
          orderVendaId: match.sellOrderId,
          executadaEm: now,
        });

        transaction.set(tokenPriceRef, {
          id: tokenPriceRef.id,
          startupId,
          preco: match.precoUnitario,
          volume: match.quantidade,
          timestamp: now,
        });

        transaction.set(buyerCreditRef, {
          userId: match.buyerId,
          valor: -valorTotal,
          tipo: 'compra',
          descricao: `Compra de ${match.quantidade} tokens`,
          createdAt: now,
        });

        transaction.set(sellerCreditRef, {
          userId: match.sellerId,
          valor: valorTotal,
          tipo: 'venda',
          descricao: `Venda de ${match.quantidade} tokens`,
          createdAt: now,
        });

      }

      if (totalCapitalAportado > 0) {
        transaction.update(startupRef, {
          capitalAportado: FieldValue.increment(totalCapitalAportado),
        });
      }

      return {
        id: orderDocRef.id,
        status: orderData.status,
        quantidadeExecutada: currentOrderExecuted,
        matchesExecutados: matches.length,
      };
    });

    res.status(201).json({
      ...result,
      message: 'Ordem criada com sucesso',
    });
  } catch (error) {
    next(error);
  }
});

router.get('/', async (req: Request, res: Response, next: any) => {
  try {
    const firebaseDb = db();
    const authReq = req as AuthRequest;

    const ordersSnapshot = await firebaseDb
      .collection('orders')
      .where('userId', '==', authReq.uid)
      .orderBy('createdAt', 'desc')
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

router.delete('/:id', async (req: Request, res: Response, next: any) => {
  try {
    const { id } = req.params;
    const firebaseDb = db();
    const authReq = req as AuthRequest;
    const initialOrderDoc = await firebaseDb.collection('orders').doc(id).get();
    const initialOrder = initialOrderDoc.data();

    if (!initialOrderDoc.exists || !initialOrder) {
      throw new AppError(404, 'Ordem não encontrada');
    }

    const startupId = String(initialOrder.startupId ?? '');
    const holdingRefs =
      initialOrder.tipo === 'venda' && startupId
        ? await getHoldingRefs(firebaseDb, authReq.uid, startupId)
        : [];

    await firebaseDb.runTransaction(async (transaction) => {
      const orderRef = initialOrderDoc.ref;
      const orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw new AppError(404, 'Ordem não encontrada');
      }

      const order = orderDoc.data() || {};
      const holding =
        order.tipo === 'venda' && holdingRefs.length > 0
          ? await readHolding(transaction, holdingRefs)
          : null;

      if (order.userId !== authReq.uid) {
        throw new AppError(403, 'Você não tem permissão para cancelar esta ordem');
      }

      if (!['aberta', 'parcial'].includes(order.status)) {
        throw new AppError(400, 'Apenas ordens abertas ou parcialmente executadas podem ser canceladas');
      }

      const now = FieldValue.serverTimestamp();

      if (holding && startupId) {
        writeHolding(
          transaction,
          holdingRefs,
          authReq.uid,
          startupId,
          {
            quantidade: holding.quantidade + remainingQuantity(order),
            precoMedioCompra: holding.precoMedioCompra,
          },
          now
        );
      }

      transaction.update(orderRef, {
        status: 'cancelada',
        updatedAt: now,
        canceladaEm: now,
      });
    });

    res.json({ message: 'Ordem cancelada com sucesso' });
  } catch (error) {
    next(error);
  }
});

export default router;
