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

function rewriteRequestPath(req: Request, path: string): void {
  const queryStart = req.url.indexOf('?');
  const query = queryStart >= 0 ? req.url.substring(queryStart) : '';
  req.url = `${path}${query}`;
}

export function requestParameter(req: Request, name: string): string {
  const value = req.query[name] ?? req.body?.[name];

  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new AppError(400, `Parâmetro obrigatório ausente: ${name}`);
  }

  return encodeURIComponent(value.trim());
}

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
