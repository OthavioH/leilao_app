// lib/main.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:leilao_app/models/leilao.dart';
import 'package:leilao_app/models/multicast_action.dart';
import 'package:leilao_app/models/user.dart';
import 'package:leilao_app/services/encryption_service.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:udp/udp.dart';
import 'dart:convert';

class AuctionScreen extends StatefulWidget {
  final String userName;
  final String multicastAddress;
  final int multicastPort;
  final String symmetricKey;
  // final Uint8List symmetricKey;

  const AuctionScreen({
    super.key,
    required this.userName,
    required this.multicastAddress,
    required this.multicastPort,
    required this.symmetricKey,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  UDP? _multicastSender;
  UDP? receiver;
  final _bidController = TextEditingController();
  StreamSubscription? _multicastDataSubscription;
  Leilao? _currentLeilao;
  MDnsClient? client;
  late Endpoint multicastEndpoint;
  late String userId;

  final formKey = GlobalKey<FormState>();

  Timer? _timer;
  Duration? tempoRestanteParaNovaOferta;

  bool isLeilaoActive = true;

  @override
  void initState() {
    super.initState();
    userId = widget.userName;
    _setupMulticast();
  }

  Future<void> _setupMulticast() async {
    try {
      final multicastEndpoint = Endpoint.multicast(InternetAddress(widget.multicastAddress), port: Port(widget.multicastPort));

      receiver = await UDP.bind(multicastEndpoint);

      receiver!.socket!.broadcastEnabled = true;
      receiver!.socket!.multicastHops = 4;
      receiver!.socket!.multicastLoopback = true;
      receiver!.socket!.readEventsEnabled = true;

      _multicastDataSubscription = receiver!.asStream().listen((datagram) {
        if (datagram == null) return;

        try {
          var message = utf8.decode(datagram.data);

          var decryptedMessage = EncryptionService.decryptWithSymmetricKey(message, widget.symmetricKey);

          final multicastAction = MulticastAction.fromJson(jsonDecode(decryptedMessage));
          if (multicastAction.active != isLeilaoActive) {
            setState(() {
              isLeilaoActive = multicastAction.active;
            });
          }
          if (multicastAction.active && multicastAction.action == 'AUCTION_STATUS') {
            final itemLeilaoAtual = Leilao.fromJson(multicastAction.data['leilao']);

            _timer?.cancel();

            if (_currentLeilao != null && itemLeilaoAtual.ofertanteAtual?.id != _currentLeilao?.ofertanteAtual?.id && itemLeilaoAtual.lanceAtual != _currentLeilao?.lanceAtual) {
              Timer.periodic(const Duration(seconds: 1), (timer) {
                if (_currentLeilao?.ofertanteAtual?.id != userId && (_currentLeilao!.lanceAtual ?? 0) > (itemLeilaoAtual.lanceAtual ?? 0)) {
                  timer.cancel();
                  return;
                }
                tempoRestanteParaNovaOferta ??= const Duration(seconds: 10);
                if (mounted) {
                  setState(() {
                    tempoRestanteParaNovaOferta = tempoRestanteParaNovaOferta! - const Duration(seconds: 1);
                  });
                }
              });
            }
            setState(() {
              _currentLeilao = itemLeilaoAtual;
              tempoRestante = itemLeilaoAtual.endTime.difference(DateTime.now());
              tempoRestante = tempoRestante.isNegative ? Duration.zero : tempoRestante;
              _timer = null;
              // init timer based on itemLeilaoAtual.endTime to update the remaining time on screen
              _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (tempoRestante.inSeconds <= 0) {
                  timer.cancel();
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog.adaptive(
                      title: const Text('O Leilão acabou!'),
                      content: Text('O leilão foi finalizado e o vencedor foi ${itemLeilaoAtual.ofertanteAtual?.id ?? 'Nenhum'}'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (mounted) {
                    setState(() {
                      final now = DateTime.now();
                      tempoRestante = itemLeilaoAtual.endTime.difference(now);
                    });
                  }
                }
              });
            });
          }
        } catch (e, stackTrace) {
          log('Error processing message: $e', stackTrace: stackTrace);
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      });

      _multicastSender = await UDP.bind(Endpoint.any(port: const Port(0)));
      _multicastSender!.socket!.broadcastEnabled = true;
      _multicastSender!.socket!.multicastHops = 128;

      var message = jsonEncode(MulticastAction(
        data: User(
          id: userId,
        ).toJson(),
        action: 'JOIN',
      ).toJson());

      var encryptedMessage = EncryptionService.encryptWithSymmetricKey(message, widget.symmetricKey);

      var messageBytes = utf8.encode(encryptedMessage);

      await _multicastSender?.send(messageBytes, multicastEndpoint);
      _multicastSender?.close();
    } catch (e, stackTrace) {
      log('Error setting up multicast: $e', stackTrace: stackTrace);
    }
  }

  // String _decryptMessage(Uint8List encrypted, Uint8List iv) {
  //   // Implementação da decriptação AES
  //   // Usar uma biblioteca como 'encrypt' para implementar
  //   return ''; // Implementar decriptação real
  // }

  Future<void> _enviarLance() async {
    if (!formKey.currentState!.validate()) return;

    final amount = double.tryParse(_bidController.text);
    if (amount == null) return;

    // final encrypted = _encryptMessage(jsonEncode(bid));
    var message = jsonEncode(MulticastAction(data: {
      "userId": userId,
      "amount": amount,
    }, action: 'BID')
        .toJson());
    var encryptedMessage = EncryptionService.encryptWithSymmetricKey(message, widget.symmetricKey);

    var messageBytes = utf8.encode(encryptedMessage);

    _multicastSender = await UDP.bind(Endpoint.any(port: const Port(0)));
    _multicastSender!.socket!.broadcastEnabled = true;
    _multicastSender!.socket!.multicastHops = 128;
    await _multicastSender?.send(
      messageBytes,
      Endpoint.multicast(
        InternetAddress(widget.multicastAddress),
        port: Port(widget.multicastPort),
      ),
    );

    formKey.currentState!.reset();
  }

  Duration tempoRestante = Duration.zero;

  @override
  void dispose() async {
    var message = jsonEncode(MulticastAction(
      data: User(
        id: userId,
      ).toJson(),
      action: 'LEAVE',
    ).toJson());
    var encryptedMessage = EncryptionService.encryptWithSymmetricKey(message, widget.symmetricKey);

    var messageBytes = utf8.encode(encryptedMessage);
    UDP.bind(Endpoint.any(port: const Port(0))).then((sender) {
      sender.socket?.broadcastEnabled = true;
      sender.socket?.multicastHops = 128;
      sender
          .send(
        messageBytes,
        Endpoint.multicast(InternetAddress(widget.multicastAddress), port: Port(widget.multicastPort)),
      )
          .whenComplete(() {
        sender.close();
      });
    });
    _multicastDataSubscription?.cancel();
    receiver?.close();
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leilão')),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_currentLeilao != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.network(
                          _currentLeilao!.item.imagem,
                          width: 100,
                          height: 100,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                      ),
                      Text(
                        _currentLeilao?.item.nome ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runAlignment: WrapAlignment.spaceEvenly,
                        alignment: WrapAlignment.spaceEvenly,
                        runSpacing: 8,
                        spacing: 16,
                        children: [
                          InfoCard(title: 'Lance inicial', data: 'R\$ ${_currentLeilao!.lanceInicial}'),
                          if (_currentLeilao!.lanceAtual != null) InfoCard(title: 'Lance atual', data: 'R\$ ${_currentLeilao!.lanceAtual}'),
                          InfoCard(title: 'Tempo restante', data: '${tempoRestante.inMinutes}:${tempoRestante.inSeconds.remainder(60).toString().padLeft(2, '0')}'),
                          InfoCard(title: 'Lance mínimo', data: 'R\$ ${_currentLeilao!.incrementoMinimoLance + (_currentLeilao!.lanceAtual ?? _currentLeilao!.lanceInicial)}'),
                          InfoCard(title: 'Ofertante atual', data: _currentLeilao!.ofertanteAtual?.id ?? 'Nenhum'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Builder(builder: (context) {
                        if (tempoRestanteParaNovaOferta == null || tempoRestanteParaNovaOferta!.inSeconds <= 0) {
                          return const SizedBox.shrink();
                        }

                        return Text('Contagem regressiva para nova oferta: ${tempoRestanteParaNovaOferta!.inSeconds}');
                      }),
                    ],
                    if (_currentLeilao != null)
                      const SizedBox(
                        height: 20,
                      ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.3,
                      child: TextFormField(
                        controller: _bidController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(labelText: 'Lance'),
                        keyboardType: TextInputType.number,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        validator: (value) {
                          if (_currentLeilao?.ofertanteAtual?.id == userId) {
                            return 'Você já tem o maior lance';
                          }
                          if (value == null || value.isEmpty || num.tryParse(value) == null) {
                            return 'Por favor, insira um valor';
                          }
                          var valorLeilaoAtual = _currentLeilao?.lanceAtual ?? _currentLeilao?.lanceInicial ?? 0;
                          if (_currentLeilao != null && num.parse(value) <= valorLeilaoAtual) {
                            return 'Lance deve ser maior que o atual';
                          }
                          if (_currentLeilao != null && num.parse(value) < valorLeilaoAtual + _currentLeilao!.incrementoMinimoLance) {
                            return 'Lance deve seguir o incremento mínimo';
                          }
                          if (_currentLeilao?.ofertanteAtual?.id == userId) {
                            return 'Você já tem o maior lance';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    ElevatedButton(
                      onPressed: _enviarLance,
                      child: const Text('Enviar lance'),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Usuários:',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 60,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentLeilao?.users.map((user) {
                                return Chip(
                                  label: Text(user.id),
                                  labelStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                );
                              }).toList() ??
                              [],
                        ),
                      ),
                    ),
                    // GridView.builder(
                    //   shrinkWrap: true,
                    //   itemCount: _currentLeilao?.users.length ?? 0,
                    //   gridDelegate:
                    //       const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 4, childAspectRatio: 1.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    //   itemBuilder: (context, index) {
                    //     var nome = _currentLeilao?.users.elementAt(index).name ?? '';
                    //     return Text(
                    //       nome,
                    //       style: const TextStyle(
                    //         color: Colors.black,
                    //         fontSize: 20,
                    //         fontWeight: FontWeight.bold,
                    //       ),
                    //     );
                    //   },
                    // ),
                  ],
                ),
              ),
            ),
          ),
          if (!isLeilaoActive)
            Container(
              width: double.maxFinite,
              height: double.maxFinite,
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Este leilão foi finalizado!', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(
                        height: 8,
                      ),
                      if (_currentLeilao?.ofertanteAtual != null)
                        Text(
                          'O vencedor foi ${_currentLeilao!.ofertanteAtual!.id}, que levou o item ${_currentLeilao!.item.nome} por: R\$${_currentLeilao!.lanceAtual}',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String data;
  const InfoCard({
    required this.title,
    required this.data,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(height: 4),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                data,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      );
}
