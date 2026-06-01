// Opções compartilhadas pelas Cloud Functions de segunda geração.
// A concorrência e o número de instâncias ficam reduzidos para manter a
// simulação previsível e evitar execuções paralelas dos jobs de preço.
import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  cpu: 'gcf_gen1',
  concurrency: 1,
  invoker: 'public',
  maxInstances: 1,
});
