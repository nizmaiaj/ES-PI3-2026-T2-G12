//Eduarda Prado Deiró

import cron from 'node-cron';
import { atualizarPrecosTokens } from '../services/tokenPriceService';

function iniciarJobs(): void {
  // Diário — a cada 1 minuto
  cron.schedule('* * * * *', async () => {
    await atualizarPrecosTokens('diario').catch((err) =>
      console.error('[diario] Erro ao atualizar preços:', err),
    );
  });

  // Semanal — a cada 2 minutos
  cron.schedule('*/2 * * * *', async () => {
    await atualizarPrecosTokens('semanal').catch((err) =>
      console.error('[semanal] Erro ao atualizar preços:', err),
    );
  });

  // Mensal — a cada 3 minutos
  cron.schedule('*/3 * * * *', async () => {
    await atualizarPrecosTokens('mensal').catch((err) =>
      console.error('[mensal] Erro ao atualizar preços:', err),
    );
  });

  // Semestral — a cada 4 minutos
  cron.schedule('*/4 * * * *', async () => {
    await atualizarPrecosTokens('semestral').catch((err) =>
      console.error('[semestral] Erro ao atualizar preços:', err),
    );
  });

  console.log('Jobs de variação de preço iniciados.');
}

export default iniciarJobs;
