//arquivo de inicializa o Firebase Admin SDK, exporta aquivos do firestore para outros arquivos ler e usar.
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

//verifica se o firebase ja foi inicalizado para não dar erro
if (getApps().length === 0) {
    initializeApp();
}
//criando e exportando uma variavel chamada db que irá representar o banco
export const db = getFirestore();