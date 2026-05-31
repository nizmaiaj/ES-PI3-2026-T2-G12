# MesclaInvest Backend API

Backend API para o MesclaInvest - plataforma acadêmica de simulação de investimentos em startups. Cada operação HTTP é publicada como uma Firebase Cloud Function independente.

## Tecnologias

- Firebase Cloud Functions com Node.js 20 e TypeScript
- Express.js reutilizado pelos handlers HTTP individuais
- Firebase Admin SDK (Firestore + Authentication)
- Helmet para segurança
- CORS configurado

## Configuração

### Pré-requisitos

- Node.js 20
- npm ou yarn
- Firebase CLI autenticado para emular ou publicar Functions

### Instalação

```bash
cd backend
npm install
```

### Variáveis de Ambiente

Copie `.env.example` para `.env` e preencha com suas credenciais:

```bash
cp .env.example .env
```

```env
PORT=3000
NODE_ENV=development

# Necessária para os endpoints /auth/login, /auth/register e
# /auth/forgot-password que usam a REST API do Firebase Auth.
FIREBASE_API_KEY=your-web-api-key

# O ambiente das Cloud Functions fornece credenciais automaticamente.
# Use estas variáveis apenas para rodar o servidor Express local com
# credenciais de service account.
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email

CORS_ORIGIN=http://localhost:5000,http://localhost:5001
```

**Nota**: A `FIREBASE_PRIVATE_KEY` deve ter `\n` convertidas para quebras de linha reais ou escapadas como `\\n`. Quando `CORS_ORIGIN` não é informado, origens HTTP são aceitas dinamicamente para facilitar o desenvolvimento local. Em produção, configure a lista separada por vírgulas.

## Desenvolvimento

### Build

```bash
npm run build
```

### Emular Cloud Functions

```bash
npm run serve
```

Com a configuração padrão do projeto, cada Function HTTP fica disponível no emulador em `http://127.0.0.1:5001/bd-pi3-1808d/us-central1/{functionName}`.

### Executar o Express local

```bash
npm run dev
```

Esse modo mantém a API em `http://localhost:3000` para desenvolvimento rápido. Ele não executa as Functions agendadas.

### Type Checking

```bash
npm run typecheck
```

### Linting

```bash
npm run lint
```

## Functions HTTP

### Autenticação

- `authRegister` - Registrar novo usuário
- `authLogin` - Fazer login
- `authForgotPassword` - Recuperação de senha

### Usuários (Requer autenticação)

- `usersGetMe` - Dados do usuário logado
- `usersInitializeProfile` - Criar perfil e carteira após cadastro pelo SDK Flutter
- `usersUpdateMfaMetadata` - Atualizar metadados do segundo fator
- `usersMarkNotificationsViewed` - Registrar visualização de notificações

### Carteira (Requer autenticação)

- `walletGet` - Saldo atual
- `walletAddCredit` - Adicionar crédito fictício
- `walletListHistory` - Histórico de movimentações

### Startups (Requer autenticação)

- `startupsList`, `startupsGet`
- `startupsListQuestions`, `startupsCreateQuestion`
- `startupsListUpdates`, `startupsListOrders`
- `startupsGetCurrentPrice`, `startupsListPrices`
- `startupsEnsureBuyOffers`

### Portfólio (Requer autenticação)

- `portfolioList` - Tokens que o usuário possui
- `portfolioGetHolding` - Posição em uma startup específica

### Ordens (Requer autenticação)

- `ordersCreateSell` - Publicar venda e reservar tokens
- `ordersBuySellOrder` - Comprar tokens de uma ordem de venda
- `ordersBuyStartupOffer` - Comprar tokens de uma oferta inicial
- `ordersBuyDirect` - Comprar tokens diretamente da startup
- `ordersListMine` - Listar ordens do usuário
- `ordersCancel` - Cancelar ordem e devolver tokens reservados

### Transações (Requer autenticação)

- `transactionsListMine` - Histórico de transações do usuário

## Segurança

- Firestore Security Rules: leituras exigem autenticação e escritas do cliente são negadas
- Escritas de negócio passam pelo backend via Firebase Admin SDK
- Leituras em tempo real continuam disponíveis pelo SDK Flutter
- Middleware de autenticação valida token Firebase em cada requisição
- Validação de dados de entrada
- Helmet para headers de segurança
- CORS configurado e restrito

## Estrutura de Dados

Ver documentação detalhada em `DATAMODEL.md` (a ser criado com descrição das coleções do Firestore).

## A Fazer

- Testes automatizados do backend
- Documentação Swagger/OpenAPI
- Rate limiting
- Logging e monitoramento

## Deploy

Na raiz do repositório:

```bash
firebase deploy --only functions
```

O `firebase.json` usa `backend/` como diretório de Functions e executa o build TypeScript antes do deploy.

Não existe uma Function agregadora `api`. Cada export de `src/index.ts` gera uma URL própria.

O job de variação de preço foi migrado para quatro Functions agendadas:

- `updateDailyTokenPrices` - a cada minuto
- `updateWeeklyTokenPrices` - a cada 2 minutos
- `updateMonthlyTokenPrices` - a cada 3 minutos
- `updateSemiannualTokenPrices` - a cada 4 minutos

## Licença

MIT
