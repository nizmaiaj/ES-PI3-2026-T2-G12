# MesclaInvest Backend API

Backend API para o MesclaInvest - plataforma acadêmica de simulação de investimentos em startups. A API Express é publicada como uma Firebase Cloud Function HTTP.

## Tecnologias

- Firebase Cloud Functions com Node.js 20 e TypeScript
- Express.js dentro da Function HTTP `api`
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

CORS_ORIGIN=http://localhost:5000
```

**Nota**: A `FIREBASE_PRIVATE_KEY` deve ter `\n` convertidas para quebras de linha reais ou escapadas como `\\n`.

## Desenvolvimento

### Build

```bash
npm run build
```

### Emular Cloud Functions

```bash
npm run serve
```

Com a configuração padrão do projeto, a API HTTP fica disponível no emulador em `http://127.0.0.1:5001/bd-pi3-1808d/us-central1/api`.

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

## Endpoints

### Autenticação

- **POST** `/auth/register` - Registrar novo usuário
- **POST** `/auth/login` - Fazer login
- **POST** `/auth/forgot-password` - Recuperação de senha

### Usuários (Requer autenticação)

- **GET** `/users/me` - Dados do usuário logado

### Carteira (Requer autenticação)

- **GET** `/wallet` - Saldo atual
- **POST** `/wallet/credit` - Adicionar crédito fictício
- **GET** `/wallet/history` - Histórico de movimentações

### Startups (Requer autenticação)

- **GET** `/startups` - Listar todas (suporta filtro `?estagio=Nova`)
- **GET** `/startups/:id` - Detalhes de uma startup
- **GET** `/startups/:id/questions` - Perguntas sobre a startup
- **POST** `/startups/:id/questions` - Enviar pergunta
- **GET** `/startups/:id/updates` - Atualizações da startup
- **GET** `/startups/:id/orders` - Livro de ofertas abertas
- **GET** `/startups/:id/prices?periodo=mensal` - Histórico de preços calculado pelas transações (`diario`, `semanal`, `mensal`, `seis_meses`, `ytd`)
- **GET** `/startups/:id/prices/current` - Preço atual

### Portfólio (Requer autenticação)

- **GET** `/portfolio` - Tokens que o usuário possui
- **GET** `/portfolio/:startupId` - Posição em uma startup específica

### Ordens (Requer autenticação)

- **POST** `/orders` - Criar nova ordem
- **GET** `/orders` - Listar ordens do usuário
- **DELETE** `/orders/:id` - Cancelar ordem

### Transações (Requer autenticação)

- **GET** `/transactions` - Histórico de transações do usuário

## Segurança

- Firestore Security Rules: `allow read, write: if false` (acesso negado)
- Todas as operações passam pelo backend via Firebase Admin SDK
- Middleware de autenticação valida token Firebase em cada requisição
- Validação de dados de entrada
- Helmet para headers de segurança
- CORS configurado e restrito

## Estrutura de Dados

Ver documentação detalhada em `DATAMODEL.md` (a ser criado com descrição das coleções do Firestore).

## Status de Implementação

### Implementado

- ✅ POST /auth/register
- ✅ POST /auth/login
- ✅ POST /auth/forgot-password (Recuperação de senha)
- ✅ GET /users/me
- ✅ GET /wallet
- ✅ POST /wallet/credit
- ✅ GET /wallet/history
- ✅ GET /startups
- ✅ GET /startups/:id
- ✅ GET /startups/:id/questions
- ✅ POST /startups/:id/questions
- ✅ GET /startups/:id/updates
- ✅ GET /startups/:id/orders
- ✅ GET /startups/:id/prices
- ✅ GET /startups/:id/prices/current
- ✅ GET /portfolio
- ✅ GET /portfolio/:startupId
- ✅ POST /orders
- ✅ GET /orders
- ✅ DELETE /orders/:id
- ✅ GET /transactions

### A Fazer

- ⏳ Motor de matching (order matching engine)
- ⏳ Transações com batch writes para atomicidade
- ⏳ Testes automatizados
- ⏳ Documentação Swagger/OpenAPI
- ⏳ Rate limiting
- ⏳ Logging e monitoramento
- ⏳ MFA (TOTP) setup e validação

## Deploy

Na raiz do repositório:

```bash
firebase deploy --only functions
```

O `firebase.json` usa `backend/` como diretório de Functions e executa o build TypeScript antes do deploy.

As rotas Express continuam sob o prefixo da Function HTTP `api`, por exemplo `/auth/login` e `/orders` após a URL da Function.

O job de variação de preço foi migrado para quatro Functions agendadas:

- `updateDailyTokenPrices` - a cada minuto
- `updateWeeklyTokenPrices` - a cada 2 minutos
- `updateMonthlyTokenPrices` - a cada 3 minutos
- `updateSemiannualTokenPrices` - a cada 4 minutos

## Licença

MIT
