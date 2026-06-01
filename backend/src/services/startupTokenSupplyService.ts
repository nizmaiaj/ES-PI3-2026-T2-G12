// Gabriel Henrique Pozeti de Faria - 25022716
// Reúne as regras de estoque dos tokens emitidos por uma startup. O serviço
// suporta documentos antigos e mantém os campos canônicos atualizados.
import { AppError } from '../middleware/errorHandler';

export interface StartupTokenSupply {
  totalTokens: number;
  tokensEmCirculacao: number;
  tokensDisponiveisParaEmissao: number;
}

/** Converte números persistidos como number ou moeda textual. */
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

/** Rejeita estoques negativos, fracionários ou ausentes. */
function assertTokenCount(value: unknown, fieldName: string): number {
  const count = parseNumber(value);

  if (!Number.isFinite(count) || !Number.isInteger(count) || count < 0) {
    throw new AppError(400, `Startup sem ${fieldName} válida`);
  }

  return count;
}

/** Lê o limite total mesmo quando o documento ainda usa um nome legado. */
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

/** Diferencia emissão primária de revenda entre usuários. */
function isStartupIssuance(transaction: FirebaseFirestore.DocumentData): boolean {
  if (transaction.origem === 'emissao_startup') return true;
  if (transaction.origem === 'mercado_secundario') return false;

  return typeof transaction.sellerId !== 'string' || transaction.sellerId.trim().length === 0;
}

/** Identifica ordens de venda que ainda reservam tokens do vendedor. */
function isReservedSellOrder(order: FirebaseFirestore.DocumentData): boolean {
  return (
    order.tipo === 'venda' &&
    ['aberta', 'parcial', 'pendente'].includes(order.status) &&
    typeof order.sellerId === 'string' &&
    order.sellerId.trim().length > 0
  );
}

/** Calcula quanto de uma ordem ainda não foi executado. */
function remainingOrderTokens(order: FirebaseFirestore.DocumentData): number {
  if (order.quantidadeRestante !== undefined) {
    return assertTokenCount(order.quantidadeRestante, 'quantidade restante da ordem');
  }

  const quantidade = assertTokenCount(order.quantidade, 'quantidade da ordem');
  const executada = assertTokenCount(order.quantidadeExecutada, 'quantidade executada da ordem');
  return Math.max(0, quantidade - executada);
}

/**
 * Reconstrói o total já emitido para startups antigas que ainda não possuem
 * `tokensEmCirculacao`. Usa o maior valor observável para não liberar emissão
 * duplicada quando parte dos dados está em formato legado.
 */
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

/** Lê o estoque atual e calcula quanto ainda pode ser emitido. */
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

/** Impede operações maiores do que o tamanho total da emissão. */
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

/** Impede novas emissões quando o estoque primário acabou. */
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

/** Persiste os campos canônicos de estoque dentro da transação corrente. */
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
