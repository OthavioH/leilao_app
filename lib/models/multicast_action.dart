class MulticastAction {
  final bool active;
  final String action;
  final dynamic data;

  MulticastAction({
    required this.data,
    required this.action,
    this.active = true,
  });

  factory MulticastAction.fromJson(Map<String, dynamic> json) {
    return MulticastAction(
      active: json['active'],
      action: json['action'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'action': action,
      'data': data,
    };
  }
}
