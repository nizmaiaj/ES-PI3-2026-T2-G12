import { HttpsError, onCall } from "firebase-functions/https";
import { buscarUsuarioPorEmail } from "../repositories/userRepository";
import { LoginInput, UsuarioDocumento } from "../types/types";


export const loginUsuario = onCall({ region: "southamerica-east1" }, async (request) => {
  const data = request.data as LoginInput;

  // Validação básica
  if (!data.email || !data.senha) {
    throw new HttpsError("invalid-argument", "Informe email e senha.");
  }

  // Tenta encontrar o usuário no banco
  const usuario = await buscarUsuarioPorEmail(data.email) as UsuarioDocumento | undefined;

  //verifica se o usuário existe
  if (!usuario) {
    throw new HttpsError("unauthenticated", "Email ou senha incorretos.");
  }

  //Verifica se a senha bate
  if (usuario.Senha !== data.senha) {
    throw new HttpsError("unauthenticated", "Email ou senha incorretos.");
  }
  //Retorno de sucesso
  return {
    success: true,
    usuario: {
      id: usuario.id,
      email: usuario.Email,
      cpf: usuario.CPF
    }
  };
});