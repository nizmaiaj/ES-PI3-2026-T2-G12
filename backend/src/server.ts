// Inicializa o servidor HTTP local. A publicação no Firebase usa `index.ts`.
import dotenv from 'dotenv';
import app from './app';
import { initializeFirebase } from './config/firebase';

dotenv.config();

initializeFirebase();

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`MesclaInvest Backend running on port ${PORT}`);
});
