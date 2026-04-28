//arquivo que recebe dados valida e repassa
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { CadastroInput } from "../types/types";
import { salvarNoBanco } from "../repositories/userRepository";

//é chamado pelo cadastroUsuario e é localizado no servidor sao paulo
export const cadastrarUsuario = onCall(
  { region: "southamerica-east1" },
  //dados inserios como input
  async (request) => {
    const data = request.data as CadastroInput;

    // Validação de dados
    if (!data.email || !data.senha || !data.cpf) {
        //caso um campo nao seja preenchido corretamente
      throw new HttpsError("invalid-argument", "Todos os campos são obrigatórios!");
    }

    try {
        //tenta salvar no db
      const userId = await salvarNoBanco(data);
      return { success: true, userId };
      //caso ocorra erro
    } catch (error) {
      throw new HttpsError("internal", "Erro ao salvar no Firestore.");
    }
  }
);