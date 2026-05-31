//Eduarda Prado Deiró

import { onSchedule } from 'firebase-functions/v2/scheduler';
import '../config/functions';
import { atualizarPrecosTokens } from '../services/tokenPriceService';

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
