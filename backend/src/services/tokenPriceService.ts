//Eduarda Prado Deiró

import { db, FieldValue } from '../config/firebase';

const PRECO_MINIMO = 1.0;

type Periodo = 'diario' | 'semanal' | 'mensal' | 'semestral';

// velocidade de retorno ao preço inicial (10% da diferença por atualização)
const THETA = 0.1;
// ruído aleatório máximo de ±0.5% por atualização
const SIGMA = 0.005;

function gerarVariacao(precoInicial: number, precoAtual: number): number {
  const reversao = THETA * (precoInicial - precoAtual) / precoAtual;
  const ruido = (Math.random() * 2 - 1) * SIGMA;
  return reversao + ruido;
}

export async function atualizarPrecosTokens(periodo: Periodo): Promise<void> {
  const firestore = db();
  const snapshot = await firestore.collection('startups').get();

  if (snapshot.empty) return;

  const batch = firestore.batch();
  const agora = new Date();

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
  }

  await batch.commit();
  console.log(`[${periodo}] Preços atualizados em ${agora.toISOString()}`);
}
