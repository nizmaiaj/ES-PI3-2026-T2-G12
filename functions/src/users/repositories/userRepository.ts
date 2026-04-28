//como os dados sao gravados no firestore
import { db } from "../../shared/firebase"; 
import { FieldValue } from "firebase-admin/firestore";
//so aceita formatos que foram definidos no types
import { CadastroInput } from "../types/types";

export async function salvarNoBanco(data: CadastroInput) {
    //cria um documento com id no firebase
  const docRef = await db.collection("Usuarios").add({
    Email: data.email,
    Senha: data.senha,
    CPF: data.cpf,
    Status_2FA: false,
    //marcar hora de gravação
    DataCriacao: FieldValue.serverTimestamp(),
  });
  //retorna o novo id criado 
  return docRef.id;
}