// Camada fina entre as telas do balcão e as Cloud Functions de negociação.
import 'functions_api_client.dart';

/// Valida dados básicos no cliente e delega as regras financeiras ao backend.
class BalcaoService {
  BalcaoService({FunctionsApiClient? apiClient})
    : _apiClient = apiClient ?? FunctionsApiClient.instance;

  final FunctionsApiClient _apiClient;

  /// Reserva tokens do vendedor em uma nova ordem aberta.
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

  /// Compra tokens de uma ordem de venda publicada por outro usuário.
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

  /// Compra tokens de uma oferta automática de emissão primária.
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

  /// Compra diretamente da startup usando seu preço atual.
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

  /// Cancela uma ordem e solicita a devolução de reservas quando necessário.
  Future<void> cancelarOrdem({
    required String usuarioId,
    required String ordemId,
  }) async {
    if (usuarioId.isEmpty) {
      throw Exception('Usuário não autenticado.');
    }

    await _apiClient.delete('ordersCancel', queryParameters: {'id': ordemId});
  }

  /// Garante que a startup tenha ofertas automáticas para exibir no balcão.
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
