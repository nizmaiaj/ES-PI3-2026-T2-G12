//Eduarda Prado Deiró

import { db, FieldValue } from '../config/firebase';

const PRECO_MINIMO = 1.0;

type Periodo = 'diario' | 'semanal' | 'mensal' | 'semestral';

const VARIACAO_MAX: Record<Periodo, number> = {
  diario:    0.05,
  semanal:   0.07,
  mensal:    0.10,
  semestral: 0.15,
};

const VARIACAO_MIN = 0.03;

function gerarVariacao(periodo: Periodo): number {
  const max = VARIACAO_MAX[periodo];
  const magnitude = VARIACAO_MIN + Math.random() * (max - VARIACAO_MIN);
  const sinal = Math.random() < 0.5 ? 1 : -1;
  return sinal * magnitude;
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
      data.precoToken ??
      data.tokenPrecoInicial ??
      1.0;

    const variacao = gerarVariacao(periodo);
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
