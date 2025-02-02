import 'package:leilao_app/models/leilao_item.dart';
import 'package:leilao_app/models/user.dart';

class Leilao {
  final String id;
  final LeilaoItem item;
  final num lanceInicial;
  final num incrementoMinimoLance;
  num? lanceAtual;
  User? ofertanteAtual;
  final DateTime endTime;
  List<User> users;

  Leilao({
    required this.id,
    required this.item,
    required this.lanceInicial,
    required this.incrementoMinimoLance,
    this.lanceAtual,
    this.ofertanteAtual,
    required this.endTime,
    required this.users,
  });

  factory Leilao.fromJson(Map<String, dynamic> json) {
    return Leilao(
      id: json['id'],
      item: LeilaoItem.fromJson(json['item']),
      lanceInicial: json['lanceInicial'],
      incrementoMinimoLance: json['incrementoMinimoLance'],
      lanceAtual: json['lanceAtual'],
      ofertanteAtual: json['ofertanteAtual'] != null ? User.fromJson(json['ofertanteAtual']) : null,
      endTime: DateTime.parse(json['endTime']),
      users: json['users'] != null ? (json['users'] as List).map((e) => User.fromJson(e)).toList() : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item': item.toJson(),
      'lanceInicial': lanceInicial,
      'incrementoMinimoLance': incrementoMinimoLance,
      'lanceAtual': lanceAtual,
      'ofertanteAtual': ofertanteAtual?.toJson(),
      'endTime': endTime.toIso8601String(),
      'users': users.map((e) => e.toJson()).toList(),
    };
  }
}
