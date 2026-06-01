import { AppError } from '../middleware/errorHandler';

export interface StartupTokenSupply {
  totalTokens: number;
  tokensEmCirculacao: number;
  tokensDisponiveisParaEmissao: number;
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

function assertTokenCount(value: unknown, fieldName: string): number {
  const count = parseNumber(value);

  if (!Number.isFinite(count) || !Number.isInteger(count) || count < 0) {
    throw new AppError(400, `Startup sem ${fieldName} válida`);
  }

  return count;
}

function totalTokenLimit(startup: FirebaseFirestore.DocumentData): number {
  return assertTokenCount(
    startup.totalTokens ??
      startup.tokensEmitidos ??
      startup.quantidadeTokens ??
      startup.tokens ??
      startup.tokensDisponiveis,
    'quantidade total de tokens'
  );
}

function isStartupIssuance(transaction: FirebaseFirestore.DocumentData): boolean {
  if (transaction.origem === 'emissao_startup') return true;
  if (transaction.origem === 'mercado_secundario') return false;

  return typeof transaction.sellerId !== 'string' || transaction.sellerId.trim().length === 0;
}

function isReservedSellOrder(order: FirebaseFirestore.DocumentData): boolean {
  return (
    order.tipo === 'venda' &&
    ['aberta', 'parcial', 'pendente'].includes(order.status) &&
    typeof order.sellerId === 'string' &&
    order.sellerId.trim().length > 0
  );
}

function remainingOrderTokens(order: FirebaseFirestore.DocumentData): number {
  if (order.quantidadeRestante !== undefined) {
    return assertTokenCount(order.quantidadeRestante, 'quantidade restante da ordem');
  }

  const quantidade = assertTokenCount(order.quantidade, 'quantidade da ordem');
  const executada = assertTokenCount(order.quantidadeExecutada, 'quantidade executada da ordem');
  return Math.max(0, quantidade - executada);
}

async function historicalIssuedTokens(
  firestoreTransaction: FirebaseFirestore.Transaction,
  firebaseDb: FirebaseFirestore.Firestore,
  startupId: string
): Promise<number> {
  const transactionsSnapshot = await firestoreTransaction.get(
    firebaseDb.collection('transactions').where('startupId', '==', startupId)
  );
  const holdingsSnapshot = await firestoreTransaction.get(
    firebaseDb.collection('tokenHoldings').where('startupId', '==', startupId)
  );
  const ordersSnapshot = await firestoreTransaction.get(
    firebaseDb.collection('orders').where('startupId', '==', startupId)
  );

  const issuedFromTransactions = transactionsSnapshot.docs.reduce((total, doc) => {
    const data = doc.data();
    if (!isStartupIssuance(data)) return total;

    return total + assertTokenCount(data.quantidade, 'quantidade histórica de tokens emitidos');
  }, 0);
  const heldTokens = holdingsSnapshot.docs.reduce(
    (total, doc) => total + assertTokenCount(doc.data().quantidade, 'quantidade de tokens em carteira'),
    0
  );
  const reservedTokens = ordersSnapshot.docs.reduce((total, doc) => {
    const data = doc.data();
    return isReservedSellOrder(data) ? total + remainingOrderTokens(data) : total;
  }, 0);

  return Math.max(issuedFromTransactions, heldTokens + reservedTokens);
}

export async function readStartupTokenSupply(
  firestoreTransaction: FirebaseFirestore.Transaction,
  firebaseDb: FirebaseFirestore.Firestore,
  startupId: string,
  startup: FirebaseFirestore.DocumentData
): Promise<StartupTokenSupply> {
  const totalTokens = totalTokenLimit(startup);
  const tokensEmCirculacao =
    startup.tokensEmCirculacao === undefined
      ? await historicalIssuedTokens(firestoreTransaction, firebaseDb, startupId)
      : assertTokenCount(startup.tokensEmCirculacao, 'quantidade de tokens em circulação');

  return {
    totalTokens,
    tokensEmCirculacao,
    tokensDisponiveisParaEmissao: Math.max(0, totalTokens - tokensEmCirculacao),
  };
}

export function assertWithinTotalTokenLimit(
  supply: StartupTokenSupply,
  quantidade: number
): void {
  if (quantidade > supply.totalTokens) {
    throw new AppError(
      400,
      `A quantidade desejada é maior que o limite total de ${supply.totalTokens} tokens da startup`
    );
  }
}

export function assertStartupCanIssueTokens(
  supply: StartupTokenSupply,
  quantidade: number
): void {
  assertWithinTotalTokenLimit(supply, quantidade);

  if (quantidade > supply.tokensDisponiveisParaEmissao) {
    throw new AppError(
      400,
      `A startup possui somente ${supply.tokensDisponiveisParaEmissao} tokens disponíveis para emissão (${supply.tokensEmCirculacao} de ${supply.totalTokens} já emitidos)`
    );
  }
}

export function writeStartupTokenSupply(
  firestoreTransaction: FirebaseFirestore.Transaction,
  startupRef: FirebaseFirestore.DocumentReference,
  supply: StartupTokenSupply,
  tokensEmCirculacao: number,
  now: FirebaseFirestore.FieldValue
): void {
  firestoreTransaction.update(startupRef, {
    tokensEmCirculacao,
    tokensDisponiveisParaEmissao: Math.max(0, supply.totalTokens - tokensEmCirculacao),
    tokenSupplyUpdatedAt: now,
  });
}
