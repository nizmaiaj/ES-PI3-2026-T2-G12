import { setGlobalOptions } from 'firebase-functions/v2';

setGlobalOptions({
  cpu: 'gcf_gen1',
  concurrency: 1,
  maxInstances: 1,
});
