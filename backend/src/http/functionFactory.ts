// Gabriel Henrique Pozeti de Faria - 25022716
// Adapta routers Express comuns para Cloud Functions independentes. Assim o
// mesmo código pode servir ao backend local e às funções publicadas.
import express, { Request } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { authMiddleware } from '../middleware/auth';
import { AppError, errorHandler } from '../middleware/errorHandler';

type HttpMethod = 'DELETE' | 'GET' | 'PATCH' | 'POST';

interface EndpointOptions {
  authenticated?: boolean;
  method: HttpMethod;
  path: string | ((req: Request) => string);
  router: express.Router;
}

/** Substitui a URL externa da Function pela rota esperada pelo router Express. */
function rewriteRequestPath(req: Request, path: string): void {
  const queryStart = req.url.indexOf('?');
  const query = queryStart >= 0 ? req.url.substring(queryStart) : '';
  req.url = `${path}${query}`;
}

/** Lê um parâmetro obrigatório enviado pela query string ou pelo corpo. */
export function requestParameter(req: Request, name: string): string {
  const value = req.query[name] ?? req.body?.[name];

  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new AppError(400, `Parâmetro obrigatório ausente: ${name}`);
  }

  return encodeURIComponent(value.trim());
}

/**
 * Cria uma aplicação Express pequena para uma única Cloud Function.
 * A função valida método HTTP, autenticação opcional e encaminha erros ao
 * mesmo tratamento usado pelo servidor local.
 */
export function createEndpoint({
  authenticated = true,
  method,
  path,
  router,
}: EndpointOptions): express.Express {
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

  if (authenticated) {
    app.use(authMiddleware as express.RequestHandler);
  }

  app.use((req, res, next) => {
    if (req.method !== method) {
      res.status(405).json({ error: `Método ${req.method} não permitido` });
      return;
    }

    try {
      rewriteRequestPath(req, typeof path === 'function' ? path(req) : path);
      router(req, res, next);
    } catch (error) {
      next(error);
    }
  });

  app.use(errorHandler);

  return app;
}
