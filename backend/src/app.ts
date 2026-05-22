import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { authMiddleware } from './middleware/auth';
import { errorHandler } from './middleware/errorHandler';
import authRoutes from './routes/auth';
import ordersRoutes from './routes/orders';
import portfolioRoutes from './routes/portfolio';
import startupsRoutes from './routes/startups';
import transactionsRoutes from './routes/transactions';
import usersRoutes from './routes/users';
import walletRoutes from './routes/wallet';

const app = express();

app.use(helmet());
app.use(
  cors({
    origin: process.env.CORS_ORIGIN || 'http://localhost:5000',
    credentials: true,
  })
);
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

export default app;
