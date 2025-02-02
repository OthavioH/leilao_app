class LeilaoItem {
  final String id;
  final String nome;
  final String imagem;

  LeilaoItem({
    required this.id,
    required this.nome,
    required this.imagem,
  });

  factory LeilaoItem.fromJson(Map<String, dynamic> json) {
    return LeilaoItem(
      id: json['id'],
      nome: json['nome'],
      imagem: json['imagem'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'imagem': imagem,
    };
  }
}