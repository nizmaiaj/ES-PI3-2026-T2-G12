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

function getOrderStatus(executed: number, total: number): OrderStatus {
  if (executed <= 0) return 'aberta';
  if (executed >= total) return 'executada';
  return 'parcial';
}

function assertIntegerTokenValue(value: unknown, fieldName: string): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
    throw new AppError(400, `${fieldName} deve ser um numero inteiro positivo`);
  }

  return value;
}

function assertPositiveMoneyValue(value: unknown, fieldName: string): number {
  if (typeof value !== 'number' || value <= 0) {
    throw new AppError(400, `${fieldName} deve ser um numero positivo`);
  }

  return value;
}

router.post('/', async (req: Request, res: Response, next: any) => {
  try {
    const { startupId, tipo } = req.body;
    const quantidade = assertIntegerTokenValue(req.body.quantidade, 'quantidade');
    const preco = assertPositiveMoneyValue(req.body.preco, 'preco');
    const authReq = req as AuthRequest;

    if (!startupId || !tipo) {
      throw new AppError(400, 'Campos obrigatorios ausentes');
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
        throw new AppError(404, 'Startup nao encontrada');
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
          throw new AppError(404, `Carteira nao encontrada para o usuario ${userId}`);
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

    await firebaseDb.runTransaction(async (transaction) => {
      const orderRef = firebaseDb.collection('orders').doc(id);
      const orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw new AppError(404, 'Ordem nao encontrada');
      }

      const order = orderDoc.data() as OrderData;

      if (order.userId !== authReq.uid) {
        throw new AppError(403, 'Voce nao tem permissao para cancelar esta ordem');
      }

      if (!['aberta', 'parcial'].includes(order.status)) {
        throw new AppError(400, 'Apenas ordens abertas ou parcialmente executadas podem ser canceladas');
      }

      transaction.update(orderRef, {
        status: 'cancelada',
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    res.json({ message: 'Ordem cancelada com sucesso' });
  } catch (error) {
    next(error);
  }
});

export default router;
