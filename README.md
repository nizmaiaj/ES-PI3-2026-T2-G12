# MesclaInvest

Aplicativo acadêmico desenvolvido para o Projeto Integrador III do curso de
Engenharia de Software da PUC-Campinas. O MesclaInvest simula um ambiente de
investimento em startups do ecossistema Mescla, com carteira fictícia, compra e
venda de tokens, acompanhamento de portfólio e informações institucionais das
empresas.

O repositório contém um app Flutter e um backend Express/TypeScript publicado
como Firebase Cloud Function. No estado atual da codebase, a maior parte das
telas do app consome Firebase diretamente pelo SDK Flutter, enquanto o backend
mantém uma API HTTP equivalente para autenticação, carteira, startups,
portfólio, ordens e transações.

## Funcionalidades

- Autenticação com Firebase Auth: cadastro, login, logout e recuperação de senha.
- Verificação em duas etapas por SMS usando Firebase Multi-Factor Authentication.
- Perfil do usuário com dados pessoais, seleção de tema claro/escuro/sistema e
  controle de 2FA.
- Home com patrimônio total, saldo em reais, tokens na carteira, gráfico de
  evolução e notificações de vendas/atualizações.
- Depósito de crédito fictício em carteira.
- Catálogo de startups com busca e filtros por estágio: `Nova`,
  `Em operação` e `Em expansão`.
- Tela de visão geral da startup com abas de resumo executivo, sociedade,
  conteúdo, atualizações e perguntas.
- Conteúdo multimídia da startup com documentos em PDF e vídeos vindos do
  Firebase Storage ou de URLs externas.
- Perguntas públicas e perguntas privadas para investidores que possuem tokens.
- Balcão de negociação com compra direta, compra por ofertas, venda de tokens,
  acompanhamento de ordens abertas/concluídas e cancelamento de ordens.
- Registro de transações, histórico de preços dos tokens e cálculo de preço
  médio por posição.

## Tecnologias

**App**

- Flutter / Dart
- Firebase Core, Auth, Cloud Firestore e Storage
- `fl_chart` para gráficos
- `video_player` e `chewie` para vídeos
- `shared_preferences` para persistência do tema
- `url_launcher` para abertura de documentos/links

**Backend**

- Node.js 20
- TypeScript
- Express
- Firebase Cloud Functions v2
- Firebase Admin SDK
- Helmet e CORS

## Arquitetura

```text
Flutter App
  |-- Firebase Auth
  |-- Cloud Firestore
  |-- Firebase Storage
  |
  +-- Backend HTTP opcional: Firebase Function `api`
        |-- Express routes
        |-- Firebase Admin SDK
        +-- Firestore/Auth
```

O backend fica em `backend/` e expõe a Function HTTP `api`. O app possui o
arquivo `lib/services/api_config.dart`, mas as telas implementadas hoje operam
principalmente via SDK do Firebase no cliente.

## Estrutura do repositório

```text
.
|-- lib/
|   |-- main.dart
|   |-- firebase_options.dart
|   |-- pages/              # Telas do app Flutter
|   |-- pages/visao_geral/  # Abas e modelos da visão da startup
|   |-- services/           # Auth, sessão, tema e regras do balcão
|   |-- theme/              # Tema Material 3 claro/escuro
|   +-- widgets/            # Navegação, seletor de tema e diálogos
|-- backend/
|   |-- src/app.ts          # App Express
|   |-- src/index.ts        # Exports das Cloud Functions
|   |-- src/server.ts       # Servidor local Express
|   |-- src/routes/         # Rotas HTTP
|   |-- src/jobs/           # Jobs agendados de preço
|   +-- src/services/       # Serviços de negócio
|-- assets/                 # Imagens usadas pelo app
|-- test/                   # Testes Flutter
|-- firebase.json
|-- firestore.rules
+-- storage.rules
```

## Modelo de dados no Firestore

As principais coleções esperadas pela aplicação são:

- `users`: perfil do usuário, CPF, telefone, preferência de notificações e 2FA.
- `wallets`: saldo fictício em reais por usuário.
- `walletCredits`: depósitos, compras e vendas registradas na carteira.
- `startups`: dados institucionais, preço do token, capital, sócios, vídeos,
  documentos e metadados da startup.
- `startups/{startupId}/questions`: perguntas públicas e privadas.
- `startups/{startupId}/updates`: comunicados e atualizações da startup.
- `startups/{startupId}/priceHistory`: histórico gerado pelos jobs agendados.
- `tokenHoldings`: quantidade de tokens por usuário e startup.
- `orders`: ordens de compra, venda e ofertas de compra do sistema.
- `transactions`: execuções de compra/venda.
- `tokenPrices`: pontos usados nos gráficos de preço dos tokens.


## Pré-requisitos

- Flutter configurado com suporte ao SDK Dart indicado em `pubspec.yaml`
  (`^3.11.4`).
- Node.js 20 e npm para o backend.
- Firebase CLI para emular ou publicar Functions.
- Projeto Firebase com Auth, Firestore e Storage habilitados.

O arquivo `lib/firebase_options.dart` está configurado para Web e Android no
projeto Firebase `bd-pi3-1808d`. As pastas de iOS, macOS, Linux e Windows
existem por serem geradas pelo Flutter, mas essas plataformas ainda precisam de
opções Firebase correspondentes antes de rodar o app nelas.

## Executando o app Flutter

Instale as dependências:

```bash
flutter pub get
```

Rode no navegador:

```bash
flutter run -d chrome
```

Ou rode em um emulador/dispositivo Android:

```bash
flutter run -d android
```

Para usar o 2FA por SMS em Android/Web, confirme no Firebase Console se Phone
Auth, domínios autorizados e configurações exigidas pela plataforma estão
habilitados.

## Executando o backend

Instale as dependências:

```bash
cd backend
npm install
```

Crie o arquivo de ambiente:

```bash
cp .env.example .env
```

Variáveis principais:

```env
PORT=3000
NODE_ENV=development
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
CORS_ORIGIN=http://localhost:5000
```

Rode o Express local:

```bash
npm run dev
```

Compile TypeScript:

```bash
npm run build
```

Emule as Cloud Functions:

```bash
npm run serve
```

Com a configuração atual, a API emulada fica em:

```text
http://127.0.0.1:5001/bd-pi3-1808d/us-central1/api
```

## Rotas do backend

Rotas públicas:

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/forgot-password`

Rotas autenticadas por Bearer token Firebase:

- `GET /users/me`
- `GET /wallet`
- `POST /wallet/credit`
- `GET /wallet/history`
- `GET /startups`
- `GET /startups/:id`
- `GET /startups/:id/questions`
- `POST /startups/:id/questions`
- `GET /startups/:id/updates`
- `GET /startups/:id/orders`
- `GET /startups/:id/prices`
- `GET /startups/:id/prices/current`
- `GET /portfolio`
- `GET /portfolio/:startupId`
- `POST /orders`
- `GET /orders`
- `DELETE /orders/:id`
- `GET /transactions`

## Jobs agendados

O backend exporta quatro Functions agendadas para variar preços simulados dos
tokens e registrar histórico em `startups/{startupId}/priceHistory`:

- `updateDailyTokenPrices`: a cada minuto.
- `updateWeeklyTokenPrices`: a cada 2 minutos.
- `updateMonthlyTokenPrices`: a cada 3 minutos.
- `updateSemiannualTokenPrices`: a cada 4 minutos.

## Qualidade e testes

Comandos úteis na raiz:

```bash
flutter analyze
flutter test
```

Comandos úteis no backend:

```bash
cd backend
npm run typecheck
npm run build
npm test
```

## Deploy Firebase

Na raiz do repositório:

```bash
firebase deploy --only functions
```

Para publicar regras junto com as Functions:

```bash
firebase deploy --only functions,firestore:rules,storage
```

## Observações de segurança

Este projeto é uma simulação acadêmica e não deve ser usado como plataforma de investimento real.

## Equipe

- Bruno Duarte Locatelli - 25007511
- Eduarda Prado Deiró - 25004440
- Gabriel Henrique Pozeti de Faria - 25022716
- Gabriel Rocca Padua dos Santos - 25002330
- Julia Da Silva Maia - 25016200

## Orientação

- Prof. Me. Mateus Pereira Dias - mateus.dias@puc-campinas.edu.br
- Profa. Renata Antonia Tadeu Arantes - renata.arantes@puc-campinas.edu.br
