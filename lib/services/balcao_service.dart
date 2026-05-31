import 'functions_api_client.dart';

class BalcaoService {
  BalcaoService({FunctionsApiClient? apiClient})
    : _apiClient = apiClient ?? FunctionsApiClient.instance;

  final FunctionsApiClient _apiClient;

  Future<void> criarOrdemVenda({
    required String vendedorId,
    required String startupId,
    required int quantidade,
    required double preco,
  }) async {
    if (vendedorId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    if (startupId.trim().isEmpty) {
      throw Exception('Startup inválida para venda.');
    }
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }
    if (preco <= 0) {
      throw Exception('Informe um preço válido para venda.');
    }

    await _apiClient.post(
      'ordersCreateSell',
      body: {'startupId': startupId, 'quantidade': quantidade, 'preco': preco},
    );
  }

  Future<void> comprarOrdemVenda({
    required String compradorId,
    required String ordemId,
    required int quantidade,
  }) async {
    if (compradorId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }

    await _apiClient.post(
      'ordersBuySellOrder',
      body: {'ordemId': ordemId, 'quantidade': quantidade},
    );
  }

  Future<void> comprarDeOferta({
    required String compradorId,
    required String ofertaId,
    required int quantidade,
  }) async {
    if (compradorId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }

    await _apiClient.post(
      'ordersBuyStartupOffer',
      body: {'ofertaId': ofertaId, 'quantidade': quantidade},
    );
  }

  Future<void> comprarDiretamente({
    required String compradorId,
    required String startupId,
    required int quantidade,
    required double preco,
  }) async {
    if (compradorId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }
    if (preco <= 0) {
      throw Exception('Preço inválido.');
    }

    await _apiClient.post(
      'ordersBuyDirect',
      body: {'startupId': startupId, 'quantidade': quantidade},
    );
  }

  Future<void> cancelarOrdem({
    required String usuarioId,
    required String ordemId,
  }) async {
    if (usuarioId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }

    await _apiClient.delete('ordersCancel', queryParameters: {'id': ordemId});
  }

  Future<void> garantirOfertasCompra(String startupId) async {
    if (startupId.trim().isEmpty) {
      return;
    }

    await _apiClient.post(
      'startupsEnsureBuyOffers',
      body: {'startupId': startupId},
    );
  }
}
