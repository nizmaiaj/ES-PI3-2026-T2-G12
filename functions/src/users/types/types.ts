//define como os dados devem ser preenchidos
export interface CadastroInput {
  email: string;
  senha: string;
  cpf: string;
  Status_2FA: boolean;
}
export type LoginInput = {
  email: string;
  senha: string;
};

// No seu arquivo types.ts, abaixo do LoginInput
export type UsuarioDocumento = {
  id: string;
  Email: string;
  Senha: string;
  CPF: string;
  Status_2FA: boolean;
};