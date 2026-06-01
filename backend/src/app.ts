// Gabriel Henrique Pozeti de Faria - 25022716
// Monta o servidor Express tradicional usado no desenvolvimento local.
// Em produção, cada Cloud Function é exposta separadamente por `index.ts`.
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
    origin: process.env.CORS_ORIGIN
      ? process.env.CORS_ORIGIN.split(',').map((origin) => origin.trim())
      : true,
    credentials: true,
  })
);
app.use(express.json());

// Cadastro, login e recuperação de senha precisam ser públicos.
app.use('/auth', authRoutes);

// As rotas abaixo só são executadas após validar o token do Firebase Auth.
app.use(authMiddleware as express.RequestHandler);

app.use('/users', usersRoutes);
app.use('/wallet', walletRoutes);
app.use('/startups', startupsRoutes);
app.use('/orders', ordersRoutes);
app.use('/transactions', transactionsRoutes);
app.use('/portfolio', portfolioRoutes);

app.use(errorHandler);

export default app;
