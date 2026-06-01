// Gabriel Henrique Pozeti de Faria - 25022716
// Ponto de entrada das Cloud Functions. Cada exportação abaixo publica um
// endpoint pequeno, mas reaproveita as regras dos routers Express.
import dotenv from 'dotenv';
import { onRequest } from 'firebase-functions/v2/https';
import './config/functions';
import { initializeFirebase } from './config/firebase';
import { createEndpoint, requestParameter } from './http/functionFactory';
import authRoutes from './routes/auth';
import ordersRoutes from './routes/orders';
import portfolioRoutes from './routes/portfolio';
import startupsRoutes from './routes/startups';
import transactionsRoutes from './routes/transactions';
import usersRoutes from './routes/users';
import walletRoutes from './routes/wallet';

dotenv.config();

initializeFirebase();

// Autenticação pública.
export const authRegister = onRequest(
  createEndpoint({ authenticated: false, method: 'POST', path: '/register', router: authRoutes })
);
export const authLogin = onRequest(
  createEndpoint({ authenticated: false, method: 'POST', path: '/login', router: authRoutes })
);
export const authForgotPassword = onRequest(
  createEndpoint({
    authenticated: false,
    method: 'POST',
    path: '/forgot-password',
    router: authRoutes,
  })
);

// Perfil do usuário autenticado.
export const usersGetMe = onRequest(
  createEndpoint({ method: 'GET', path: '/me', router: usersRoutes })
);
export const usersInitializeProfile = onRequest(
  createEndpoint({ method: 'POST', path: '/initialize-profile', router: usersRoutes })
);
export const usersUpdateMfaMetadata = onRequest(
  createEndpoint({ method: 'PATCH', path: '/mfa', router: usersRoutes })
);
export const usersMarkNotificationsViewed = onRequest(
  createEndpoint({ method: 'PATCH', path: '/notifications-viewed', router: usersRoutes })
);

// Carteira em reais e seu extrato.
export const walletGet = onRequest(
  createEndpoint({ method: 'GET', path: '/', router: walletRoutes })
);
export const walletAddCredit = onRequest(
  createEndpoint({ method: 'POST', path: '/credit', router: walletRoutes })
);
export const walletListHistory = onRequest(
  createEndpoint({ method: 'GET', path: '/history', router: walletRoutes })
);

// Catálogo, conteúdo e preços das startups.
export const startupsList = onRequest(
  createEndpoint({ method: 'GET', path: '/', router: startupsRoutes })
);
export const startupsGet = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'id')}`,
    router: startupsRoutes,
  })
);
export const startupsListQuestions = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}/questions`,
    router: startupsRoutes,
  })
);
export const startupsCreateQuestion = onRequest(
  createEndpoint({
    method: 'POST',
    path: (req) => `/${requestParameter(req, 'startupId')}/questions`,
    router: startupsRoutes,
  })
);
export const startupsListUpdates = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}/updates`,
    router: startupsRoutes,
  })
);
export const startupsListOrders = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}/orders`,
    router: startupsRoutes,
  })
);
export const startupsGetCurrentPrice = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}/prices/current`,
    router: startupsRoutes,
  })
);
export const startupsListPrices = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}/prices`,
    router: startupsRoutes,
  })
);
export const startupsEnsureBuyOffers = onRequest(
  createEndpoint({
    method: 'POST',
    path: (req) => `/${requestParameter(req, 'startupId')}/ensure-buy-offers`,
    router: startupsRoutes,
  })
);

// Posições de tokens mantidas pelo usuário.
export const portfolioList = onRequest(
  createEndpoint({ method: 'GET', path: '/', router: portfolioRoutes })
);
export const portfolioGetHolding = onRequest(
  createEndpoint({
    method: 'GET',
    path: (req) => `/${requestParameter(req, 'startupId')}`,
    router: portfolioRoutes,
  })
);

// Criação, execução, consulta e cancelamento de ordens.
export const ordersCreateSell = onRequest(
  createEndpoint({ method: 'POST', path: '/sell', router: ordersRoutes })
);
export const ordersBuySellOrder = onRequest(
  createEndpoint({ method: 'POST', path: '/buy-sell-order', router: ordersRoutes })
);
export const ordersBuyStartupOffer = onRequest(
  createEndpoint({ method: 'POST', path: '/buy-startup-offer', router: ordersRoutes })
);
export const ordersBuyDirect = onRequest(
  createEndpoint({ method: 'POST', path: '/buy-direct', router: ordersRoutes })
);
export const ordersListMine = onRequest(
  createEndpoint({ method: 'GET', path: '/', router: ordersRoutes })
);
export const ordersCancel = onRequest(
  createEndpoint({
    method: 'DELETE',
    path: (req) => `/${requestParameter(req, 'id')}`,
    router: ordersRoutes,
  })
);

// Histórico consolidado de compras e vendas do usuário.
export const transactionsListMine = onRequest(
  createEndpoint({ method: 'GET', path: '/', router: transactionsRoutes })
);

// Jobs agendados que simulam a evolução do preço dos tokens.
export {
  updateDailyTokenPrices,
  updateMonthlyTokenPrices,
  updateSemiannualTokenPrices,
  updateWeeklyTokenPrices,
} from './jobs/tokenPriceJob';
