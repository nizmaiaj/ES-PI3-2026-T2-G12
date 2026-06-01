//Eduarda Prado Deiró
// Agenda execuções frequentes para demonstrar a movimentação do gráfico em
// ambiente acadêmico. Em produção, os intervalos deveriam refletir períodos reais.

import { onSchedule } from 'firebase-functions/v2/scheduler';
import '../config/functions';
import { atualizarPrecosTokens } from '../services/tokenPriceService';

// Cada job registra o período no histórico; todos reutilizam a mesma regra.
export const updateDailyTokenPrices = onSchedule('* * * * *', () =>
  atualizarPrecosTokens('diario')
);

export const updateWeeklyTokenPrices = onSchedule('*/2 * * * *', () =>
  atualizarPrecosTokens('semanal')
);

export const updateMonthlyTokenPrices = onSchedule('*/3 * * * *', () =>
  atualizarPrecosTokens('mensal')
);

export const updateSemiannualTokenPrices = onSchedule('*/4 * * * *', () =>
  atualizarPrecosTokens('semestral')
);
