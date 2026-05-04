//lógica de comunicação(como os dados sao gravados no firestore)
import { db } from "../../shared/firebase"; 
import { FieldValue } from "firebase-admin/firestore";

//so aceita formatos que foram definidos no types
import { CadastroInput, UsuarioDocumento } from "../types/types";

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
  // Busca os dados do usuário para conferir no login
export async function buscarUsuarioPorEmail(email: string): Promise<UsuarioDocumento | undefined> {{
  const snapshot = await db.collection("Usuarios")
    .where("Email", "==", email)
    .limit(1)
    .get();

  if (snapshot.empty) {
    return undefined;
  }
  
  const doc = snapshot.docs[0];
  const data = doc.data();
  return { 
    id: doc.id, 
    Email: data.Email,
    Senha: data.Senha,
    CPF: data.CPF,
    Status_2FA: data.Status_2FA 
  } as UsuarioDocumento;
};
}
