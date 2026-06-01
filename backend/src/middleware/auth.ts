// Middleware aplicado às rotas privadas. Ele extrai o Bearer token enviado
// pelo aplicativo e disponibiliza o UID validado para os handlers seguintes.
import { Request, Response, NextFunction } from 'express';
import { auth } from '../config/firebase';

export interface AuthRequest extends Request {
  uid: string;
  user?: any;
}

/** Valida o ID token do Firebase Auth e anexa o UID à requisição. */
export async function authMiddleware(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];

    if (!token) {
      res.status(401).json({ error: 'Token de autorização ausente' });
      return;
    }

    const decodedToken = await auth().verifyIdToken(token);
    (req as AuthRequest).uid = decodedToken.uid;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Token inválido ou expirado' });
  }
}
