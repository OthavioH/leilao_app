// lib/main.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:leilao_app/core/helpers/environment_helper.dart';
import 'package:leilao_app/models/leilao.dart';
import 'package:leilao_app/models/multicast_action.dart';
import 'package:leilao_app/models/user.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:udp/udp.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

class AuctionScreen extends StatefulWidget {
  final String userName;
  final String multicastAddress;
  final int multicastPort;
  // final Uint8List symmetricKey;

  const AuctionScreen({
    super.key,
    required this.userName,
    required this.multicastAddress,
    required this.multicastPort,
    // required this.symmetricKey,
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

  @override
  void initState() {
    super.initState();
    _setupMulticast();
  }

  Future<void> _setupMulticast() async {
    multicastEndpoint = Endpoint.multicast(InternetAddress(widget.multicastAddress), port: const Port(27010));

    receiver = await UDP.bind(multicastEndpoint);
    receiver!.socket!.broadcastEnabled = true;
    receiver!.socket!.multicastHops = 4;
    receiver!.socket!.multicastLoopback = true;
    receiver!.socket!.readEventsEnabled = true;

    var multicastAddress = InternetAddress(widget.multicastAddress);
    if (!multicastAddress.isMulticast) {
      throw ArgumentError('Invalid multicast address: ${widget.multicastAddress}');
    }

    _multicastDataSubscription = receiver!.asStream().listen((datagram) {
      if (datagram == null) return;

      try {
        var message = utf8.decode(datagram.data);

        final multicastAction = MulticastAction.fromJson(jsonDecode(message));
        if (multicastAction.active && multicastAction.action == 'AUCTION_STATUS') {
          final itemLeilaoAtual = Leilao.fromJson(multicastAction.data['leilao']);

          setState(() => _currentLeilao = itemLeilaoAtual);
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    });

    _multicastSender = await UDP.bind(Endpoint.any());

    userId = const Uuid().v4();
    var message = jsonEncode(MulticastAction(
      data: User(
        id: userId,
        name: widget.userName,
      ).toJson(),
      action: 'JOIN',
    ).toJson());
    var messageBytes = utf8.encode(message);
    await _multicastSender?.send(
      messageBytes,
      Endpoint.multicast(InternetAddress(EnvironmentHelper.apiIP), port: const Port(27010)),
    );
  }

  String _decryptMessage(Uint8List encrypted, Uint8List iv) {
    // Implementação da decriptação AES
    // Usar uma biblioteca como 'encrypt' para implementar
    return ''; // Implementar decriptação real
  }

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
    var messageBytes = utf8.encode(message);
    await _multicastSender?.send(
      messageBytes,
      Endpoint.multicast(InternetAddress(EnvironmentHelper.apiIP), port: const Port(27010)),
    );

    formKey.currentState!.reset();
  }

  Uint8List _encryptMessage(String message) {
    // Implementação da encriptação AES
    // Usar uma biblioteca como 'encrypt' para implementar
    return Uint8List(0); // Implementar encriptação real
  }

  @override
  void dispose() async {
    var message = jsonEncode(MulticastAction(
      data: User(
        id: userId,
        name: widget.userName,
      ).toJson(),
      action: 'LEAVE',
    ).toJson());
    var messageBytes = utf8.encode(message);
    _multicastSender
        ?.send(
      messageBytes,
      Endpoint.multicast(InternetAddress(EnvironmentHelper.apiIP), port: const Port(27010)),
    )
        .whenComplete(() {
      _multicastSender?.close();
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
      body: Form(
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
                  ),
                ),
                Text('Item: ${_currentLeilao!.item.nome}'),
                Text('Lance inicial: R\$ ${_currentLeilao!.lanceInicial}'),
                Text('Lance atual: R\$ ${_currentLeilao!.lanceAtual}'),
                Text('Lance mínimo: R\$ ${_currentLeilao!.incrementoMinimoLance}'),
                Text('Ofertante atual: ${_currentLeilao!.ofertanteAtual?.name}'),
                Text('Tempo restante: ${_currentLeilao!.endTime.difference(DateTime.now()).inMinutes} minutos'),
              ],
              const SizedBox(
                height: 20,
              ),
              TextFormField(
                controller: _bidController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: const InputDecoration(labelText: 'Lance'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty || double.tryParse(value) == null) {
                    return 'Por favor, insira um valor';
                  }
                  var valorLeilaoAtual = _currentLeilao?.lanceAtual ?? _currentLeilao?.lanceInicial ?? 0;
                  if (_currentLeilao != null && double.parse(value) <= valorLeilaoAtual) {
                    return 'Lance deve ser maior que o atual';
                  }
                  if (_currentLeilao != null && num.parse(value) < valorLeilaoAtual + _currentLeilao!.incrementoMinimoLance) {
                    return 'Lance deve seguir o incremento mínimo';
                  }
                  if (_currentLeilao?.ofertanteAtual?.id == userId) {
                    return 'Você já é o maior lance';
                  }
                  return null;
                },
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed: _enviarLance,
                child: const Text('Enviar lance'),
              ),
              const SizedBox(height: 20),
              ListView.builder(
                shrinkWrap: true,
                itemCount: _currentLeilao?.users.length ?? 0,
                itemBuilder: (context, index) {
                  var nome = _currentLeilao?.users.elementAt(index).name ?? '';
                  return Text(
                    nome,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
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
    );
  }
}
