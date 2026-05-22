import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { initializeFirebase } from './config/firebase';
import { authMiddleware } from './middleware/auth';
import authRoutes from './routes/auth';
import usersRoutes from './routes/users';
import walletRoutes from './routes/wallet';
import startupsRoutes from './routes/startups';
import ordersRoutes from './routes/orders';
import transactionsRoutes from './routes/transactions';
import portfolioRoutes from './routes/portfolio';
import { errorHandler } from './middleware/errorHandler';
import iniciarJobs from './jobs/tokenPriceJob';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

initializeFirebase();

app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || 'http://localhost:5000',
  credentials: true,
}));
app.use(express.json());

app.use('/auth', authRoutes);

app.use(authMiddleware as express.RequestHandler);

app.use('/users', usersRoutes);
app.use('/wallet', walletRoutes);
app.use('/startups', startupsRoutes);
app.use('/orders', ordersRoutes);
app.use('/transactions', transactionsRoutes);
app.use('/portfolio', portfolioRoutes);

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`🚀 MesclaInvest Backend running on port ${PORT}`);
  iniciarJobs();
});
