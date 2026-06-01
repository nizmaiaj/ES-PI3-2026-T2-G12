//Eduarda Prado Deiró
// Simula a evolução dos preços dos tokens e atualiza as ofertas automáticas de
// compra. Os jobs chamam este serviço com diferentes identificadores de período.

import { db, FieldValue } from '../config/firebase';

const PRECO_MINIMO = 1.0;

type Periodo = 'diario' | 'semanal' | 'mensal' | 'semestral';

// velocidade de retorno ao preço inicial (10% da diferença por atualização)
const THETA = 0.1;
// ruído aleatório máximo de ±0.5% por atualização
const SIGMA = 0.005;

// Mesmos fatores usados em ensure-buy-offers
const SYSTEM_OFFER_FACTORS = [0.885, 0.91, 0.93, 0.95, 0.97];

/** Combina retorno gradual ao preço inicial com uma pequena variação aleatória. */
function gerarVariacao(precoInicial: number, precoAtual: number): number {
  const reversao = THETA * (precoInicial - precoAtual) / precoAtual;
  const ruido = (Math.random() * 2 - 1) * SIGMA;
  return reversao + ruido;
}

/** Atualiza todas as startups e registra um ponto histórico para cada preço. */
export async function atualizarPrecosTokens(periodo: Periodo): Promise<void> {
  const firestore = db();
  const snapshot = await firestore.collection('startups').get();

  if (snapshot.empty) return;

  const batch = firestore.batch();
  const agora = new Date();

  // Mapa de novo preço por startupId, para usar ao atualizar ofertas
  const novosPrecosMap = new Map<string, number>();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const precoAtual: number =
      data.valorToken ??
      data.tokenPrecoInicial ??
      1.0;

    const precoInicial: number =
      data.tokenPrecoInicial ??
      precoAtual;

    const variacao = gerarVariacao(precoInicial, precoAtual);
    const novoPreco = Math.max(PRECO_MINIMO, precoAtual * (1 + variacao));
    const novoPrecoArredondado = Math.round(novoPreco * 100) / 100;

    batch.update(doc.ref, { valorToken: novoPrecoArredondado });

    const histRef = doc.ref.collection('priceHistory').doc();
    batch.set(histRef, {
      preco: novoPrecoArredondado,
      precoanterior: precoAtual,
      variacao: Math.round(variacao * 10000) / 100,
      periodo,
      registradoEm: FieldValue.serverTimestamp(),
    });

    novosPrecosMap.set(doc.id, novoPrecoArredondado);
  }

  // Busca todas as ofertas fictícias de todas as startups de uma vez
  const offerRefs = snapshot.docs.flatMap((doc) =>
    SYSTEM_OFFER_FACTORS.map((_, i) =>
      firestore.collection('orders').doc(`system_buy_offer_${doc.id}_${i}`)
    )
  );

  if (offerRefs.length > 0) {
    const offerSnaps = await firestore.getAll(...offerRefs);

    for (const snap of offerSnaps) {
      if (!snap.exists) continue;

      const offerData = snap.data()!;
      const status: string = offerData.status ?? '';

      if (status !== 'aberta' && status !== 'parcial') continue;

      const startupId: string = offerData.startupId ?? '';
      const novoPreco = novosPrecosMap.get(startupId);
      if (!novoPreco) continue;

      // Recupera o fator a partir do índice no ID do documento (ex: _2 → índice 2)
      const docId = snap.ref.id;
      const indexMatch = docId.match(/_(\d+)$/);
      if (!indexMatch) continue;
      const factorIndex = parseInt(indexMatch[1], 10);
      const factor = SYSTEM_OFFER_FACTORS[factorIndex];
      if (factor === undefined) continue;

      const novoPrecoOferta = Math.round(novoPreco * factor * 100) / 100;
      batch.update(snap.ref, {
        preco: novoPrecoOferta,
        precoUnitario: novoPrecoOferta,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }

  await batch.commit();
  console.log(`[${periodo}] Preços atualizados em ${agora.toISOString()}`);
}
