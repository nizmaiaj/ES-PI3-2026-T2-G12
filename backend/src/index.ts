import dotenv from 'dotenv';
import { onRequest } from 'firebase-functions/v2/https';
import app from './app';
import { initializeFirebase } from './config/firebase';

dotenv.config();

initializeFirebase();

export const api = onRequest(app);

export {
  updateDailyTokenPrices,
  updateMonthlyTokenPrices,
  updateSemiannualTokenPrices,
  updateWeeklyTokenPrices,
} from './jobs/tokenPriceJob';
