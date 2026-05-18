import 'package:cloud_firestore/cloud_firestore.dart';

class BalcaoService {
  BalcaoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> criarOrdemVenda({
    required String vendedorId,
    required String startupId,
    required int quantidade,
    required double preco,
  }) async {
    if (startupId.trim().isEmpty) {
      throw Exception('Startup inválida para venda.');
    }

    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }

    if (preco <= 0) {
      throw Exception('Informe um preço válido para venda.');
    }

    final holdingRef = await _normalizarHoldingRef(vendedorId, startupId);
    final orderRef = _firestore.collection('orders').doc();
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final holdingDoc = await transaction.get(holdingRef);

      if (!holdingDoc.exists) {
        throw Exception('Tokens não encontrados na carteira.');
      }

      final holding = holdingDoc.data();
      final quantidadeAtual = _numero(holding?['quantidade']).toInt();

      if (quantidadeAtual < quantidade) {
        throw Exception('Tokens insuficientes para venda.');
      }

      transaction.set(holdingRef, {
        'userId': vendedorId,
        'startupId': startupId,
        'quantidade': quantidadeAtual - quantidade,
        'updatedAt': now,
      }, SetOptions(merge: true));

      transaction.set(orderRef, {
        'id': orderRef.id,
        'userId': vendedorId,
        'sellerId': vendedorId,
        'startupId': startupId,
        'tipo': 'venda',
        'quantidade': quantidade,
        'quantidadeExecutada': 0,
        'quantidadeRestante': quantidade,
        'preco': preco,
        'precoUnitario': preco,
        'status': 'aberta',
        'createdAt': now,
        'updatedAt': now,
      });
    });
  }

  Future<void> comprarOrdemVenda({
    required String compradorId,
    required String ordemId,
    required int quantidade,
  }) async {
    if (quantidade <= 0) {
      throw Exception('Informe uma quantidade válida de tokens.');
    }

    final orderRef = _firestore.collection('orders').doc(ordemId);
    final orderSnapshot = await orderRef.get();
    final orderData = orderSnapshot.data();

    if (orderData == null) {
      throw Exception('Oferta não encontrada.');
    }

    final startupId = _texto(orderData['startupId']);
    if (startupId.isEmpty) {
      throw Exception('Oferta inválida.');
    }

    final compradorHoldingRef = await _normalizarHoldingRef(
      compradorId,
      startupId,
    );
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Oferta não encontrada.');
      }

      final order = orderDoc.data() ?? {};
      final tipo = _texto(order['tipo']).toLowerCase();
      final status = _texto(order['status']).toLowerCase();
      final vendedorId = _texto(order['sellerId'] ?? order['userId']);
      final startupId = _texto(order['startupId']);
      final preco = _numero(order['preco'] ?? order['precoUnitario']);
      final quantidadeOriginal = _numero(order['quantidade']).toInt();
      final quantidadeExecutada = _numero(order['quantidadeExecutada']).toInt();
      final quantidadeRestante = _quantidadeRestante(order);

      if (tipo != 'venda' || !_statusAberto(status)) {
        throw Exception('Esta oferta não está mais disponível.');
      }

      if (vendedorId.isEmpty || vendedorId == compradorId) {
        throw Exception('Não é possível comprar a própria oferta.');
      }

      if (startupId.isEmpty || preco <= 0) {
        throw Exception('Oferta inválida.');
      }

      if (quantidadeRestante < quantidade) {
        throw Exception('Quantidade indisponível nesta oferta.');
      }

      final vendedorWalletRef = _firestore
          .collection('wallets')
          .doc(vendedorId);
      final compradorWalletRef = _firestore
          .collection('wallets')
          .doc(compradorId);

      final compradorWalletDoc = await transaction.get(compradorWalletRef);
      final vendedorWalletDoc = await transaction.get(vendedorWalletRef);
      final compradorHoldingDoc = await transaction.get(compradorHoldingRef);

      if (!compradorWalletDoc.exists) {
        throw Exception('Carteira do comprador não encontrada.');
      }

      final total = preco * quantidade;
      final saldoComprador = _numero(compradorWalletDoc.data()?['saldoReais']);

      if (saldoComprador < total) {
        throw Exception('Saldo insuficiente na carteira.');
      }

      final saldoVendedor = _numero(vendedorWalletDoc.data()?['saldoReais']);
      final holding = compradorHoldingDoc.data();
      final quantidadeAtualComprador = _numero(holding?['quantidade']).toInt();
      final precoMedioAtual = _numero(holding?['precoMedioCompra']);
      final novaQuantidadeComprador = quantidadeAtualComprador + quantidade;
      final novoPrecoMedio =
          ((quantidadeAtualComprador * precoMedioAtual) + total) /
          novaQuantidadeComprador;
      final novaExecutada = quantidadeExecutada + quantidade;
      final novaRestante = quantidadeOriginal - novaExecutada;
      final statusAtualizado = novaRestante <= 0 ? 'executada' : 'parcial';

      final compraOrderRef = _firestore.collection('orders').doc();
      final transactionRef = _firestore.collection('transactions').doc();
      final tokenPriceRef = _firestore.collection('tokenPrices').doc();
      final buyerWalletCreditRef = _firestore.collection('walletCredits').doc();
      final sellerWalletCreditRef = _firestore
          .collection('walletCredits')
          .doc();

      transaction.update(compradorWalletRef, {
        'saldoReais': saldoComprador - total,
        'updatedAt': now,
      });

      transaction.set(vendedorWalletRef, {
        'userId': vendedorId,
        'saldoReais': saldoVendedor + total,
        'updatedAt': now,
      }, SetOptions(merge: true));

      transaction.set(compradorHoldingRef, {
        'userId': compradorId,
        'startupId': startupId,
        'quantidade': novaQuantidadeComprador,
        'precoMedioCompra': novoPrecoMedio,
        'updatedAt': now,
      }, SetOptions(merge: true));

      transaction.update(orderRef, {
        'quantidadeExecutada': novaExecutada,
        'quantidadeRestante': novaRestante < 0 ? 0 : novaRestante,
        'status': statusAtualizado,
        'updatedAt': now,
        if (statusAtualizado == 'executada') 'executadaEm': now,
      });

      transaction.set(compraOrderRef, {
        'id': compraOrderRef.id,
        'userId': compradorId,
        'buyerId': compradorId,
        'sellerId': vendedorId,
        'startupId': startupId,
        'tipo': 'compra',
        'quantidade': quantidade,
        'quantidadeExecutada': quantidade,
        'quantidadeRestante': 0,
        'preco': preco,
        'precoUnitario': preco,
        'status': 'executada',
        'orderVendaId': orderRef.id,
        'createdAt': now,
        'updatedAt': now,
        'executadaEm': now,
      });

      transaction.set(transactionRef, {
        'id': transactionRef.id,
        'startupId': startupId,
        'buyerId': compradorId,
        'sellerId': vendedorId,
        'quantidade': quantidade,
        'precoUnitario': preco,
        'valorTotal': total,
        'orderCompraId': compraOrderRef.id,
        'orderVendaId': orderRef.id,
        'executadaEm': now,
      });

      transaction.set(tokenPriceRef, {
        'id': tokenPriceRef.id,
        'startupId': startupId,
        'preco': preco,
        'volume': quantidade,
        'timestamp': now,
      });

      transaction.set(buyerWalletCreditRef, {
        'userId': compradorId,
        'valor': -total,
        'tipo': 'compra',
        'descricao': 'Compra de $quantidade tokens',
        'createdAt': now,
      });

      transaction.set(sellerWalletCreditRef, {
        'userId': vendedorId,
        'valor': total,
        'tipo': 'venda',
        'descricao': 'Venda de $quantidade tokens',
        'createdAt': now,
      });
    });
  }

  Future<void> cancelarOrdem({
    required String usuarioId,
    required String ordemId,
  }) async {
    final orderRef = _firestore.collection('orders').doc(ordemId);
    final orderSnapshot = await orderRef.get();
    final orderData = orderSnapshot.data();

    if (orderData == null) {
      throw Exception('Ordem não encontrada.');
    }

    final startupId = _texto(orderData['startupId']);
    if (startupId.isEmpty) {
      throw Exception('Ordem inválida.');
    }

    final holdingRef = await _normalizarHoldingRef(usuarioId, startupId);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Ordem não encontrada.');
      }

      final order = orderDoc.data() ?? {};
      final donoId = _texto(order['userId'] ?? order['sellerId']);
      final tipo = _texto(order['tipo']).toLowerCase();
      final status = _texto(order['status']).toLowerCase();
      final quantidadeRestante = _quantidadeRestante(order);

      if (donoId != usuarioId) {
        throw Exception('Você não pode cancelar esta ordem.');
      }

      if (!_statusAberto(status)) {
        throw Exception('Esta ordem não está aberta.');
      }

      if (tipo == 'venda' && quantidadeRestante > 0) {
        final holdingDoc = await transaction.get(holdingRef);
        final holding = holdingDoc.data();
        final quantidadeAtual = _numero(holding?['quantidade']).toInt();

        transaction.set(holdingRef, {
          'userId': usuarioId,
          'startupId': startupId,
          'quantidade': quantidadeAtual + quantidadeRestante,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }

      transaction.update(orderRef, {
        'status': 'cancelada',
        'updatedAt': now,
        'canceladaEm': now,
      });
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> _normalizarHoldingRef(
    String uid,
    String startupId,
  ) async {
    final canonicalRef = _firestore
        .collection('tokenHoldings')
        .doc(_holdingDocId(uid, startupId));
    final docs = await _buscarHoldingDocs(uid, startupId);
    final refs = <DocumentReference<Map<String, dynamic>>>[
      canonicalRef,
      for (final doc in docs)
        if (doc.reference.path != canonicalRef.path) doc.reference,
    ];

    if (docs.length == 1 && docs.first.reference.path == canonicalRef.path) {
      return canonicalRef;
    }

    await _firestore.runTransaction((transaction) async {
      final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];

      for (final ref in refs) {
        snapshots.add(await transaction.get(ref));
      }

      var quantidadeTotal = 0;
      var custoTotal = 0.0;

      for (final snapshot in snapshots) {
        final data = snapshot.data();
        if (data == null) continue;

        final quantidade = _numero(data['quantidade']).toInt();
        final precoMedioCompra = _numero(data['precoMedioCompra']);

        quantidadeTotal += quantidade;
        custoTotal += quantidade * precoMedioCompra;
      }

      if (quantidadeTotal > 0) {
        transaction.set(canonicalRef, {
          'userId': uid,
          'startupId': startupId,
          'quantidade': quantidadeTotal,
          'precoMedioCompra': custoTotal / quantidadeTotal,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      for (final snapshot in snapshots) {
        if (snapshot.reference.path != canonicalRef.path && snapshot.exists) {
          transaction.delete(snapshot.reference);
        }
      }
    });

    return canonicalRef;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _buscarHoldingDocs(
    String uid,
    String startupId,
  ) async {
    final snapshot = await _firestore
        .collection('tokenHoldings')
        .where('userId', isEqualTo: uid)
        .get();

    return snapshot.docs
        .where((doc) => _texto(doc.data()['startupId']) == startupId)
        .toList();
  }

  String _holdingDocId(String uid, String startupId) => '${uid}_$startupId';
}

bool _statusAberto(String status) {
  return status == 'aberta' ||
      status == 'parcial' ||
      status == 'pendente' ||
      status.contains('aguardando');
}

int _quantidadeRestante(Map<String, dynamic> order) {
  final restante = _numero(order['quantidadeRestante']).toInt();
  if (restante > 0) return restante;

  final quantidade = _numero(order['quantidade']).toInt();
  final executada = _numero(order['quantidadeExecutada']).toInt();
  final calculada = quantidade - executada;
  return calculada < 0 ? 0 : calculada;
}

String _texto(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;

  final texto = value.toString().trim();
  return texto.isEmpty ? fallback : texto;
}

double _numero(dynamic value, {double fallback = 0}) {
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();

  if (value is String) {
    final texto = value.replaceAll('R\$', '').replaceAll(' ', '').trim();
    final normalizado = texto.contains(',')
        ? texto.replaceAll('.', '').replaceAll(',', '.')
        : texto;

    return double.tryParse(normalizado) ?? fallback;
  }

  return fallback;
}
