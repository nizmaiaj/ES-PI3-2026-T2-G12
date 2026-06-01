// Gabriel Henrique Pozeti de Faria - 25022716
// Padroniza erros esperados da aplicação e impede que detalhes internos sejam
// devolvidos ao cliente quando ocorre uma falha inesperada.
import { Request, Response, NextFunction } from 'express';

/** Erro de negócio com status HTTP conhecido. */
export class AppError extends Error {
  constructor(
    public statusCode: number,
    message: string
  ) {
    super(message);
  }
}

/** Último middleware da cadeia Express: converte exceções em respostas JSON. */
export function errorHandler(
  err: Error | AppError,
  req: Request,
  res: Response,
  next: NextFunction
) {
  console.error(err);

  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: err.message });
    return;
  }

  res.status(500).json({ error: 'Erro interno do servidor' });
}
