import 'package:leilao_app/models/user.dart';

class LeilaoItem {
  final String id;
  final String nome;
  final double lanceInicial;
  final double incrementoMinimoLance;
  double? lanceAtual;
  User? ofertanteAtual;
  final DateTime endTime;

  LeilaoItem({
    required this.id,
    required this.nome,
    required this.lanceInicial,
    required this.incrementoMinimoLance,
    this.lanceAtual,
    this.ofertanteAtual,
    required this.endTime,
  });

  factory LeilaoItem.fromJson(Map<String, dynamic> json) {
    return LeilaoItem(
      id: json['id'],
      nome: json['nome'],
      lanceInicial: json['lanceInicial'],
      incrementoMinimoLance: json['incrementoMinimoLance'],
      lanceAtual: json['lanceAtual'],
      ofertanteAtual: json['ofertanteAtual'] != null ? User.fromJson(json['ofertanteAtual']) : null,
      endTime: DateTime.parse(json['endTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'lanceInicial': lanceInicial,
      'incrementoMinimoLance': incrementoMinimoLance,
      'lanceAtual': lanceAtual,
      'ofertanteAtual': ofertanteAtual?.toJson(),
      'endTime': endTime.toIso8601String(),
    };
  }
}
