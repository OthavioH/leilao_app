// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:leilao_app/core/helpers/environment_helper.dart';
import 'package:leilao_app/models/leilao.dart';
import 'package:leilao_app/models/multicast_action.dart';
import 'package:mcast_lock/mcast_lock.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'package:udp/udp.dart';
import 'dart:convert';
import 'dart:typed_data';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> joinLeilao() async {
    setState(() => _isLoading = true);

    try {
      // Gerar par de chaves
      // final keyPair = await Ed25519().newKeyPair();
      // final publicKey = await keyPair.extractPublicKey();
      // final publicKeyBytes = publicKey.bytes;

      // Registrar usuário
      final response = await http.post(
        Uri.parse('${EnvironmentHelper.apiUrl}/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          // 'publicKey': base64Encode(publicKeyBytes),
        }),
      );

      if (response.statusCode == 200) {
        final joinData = jsonDecode(response.body);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AuctionScreen(
                userId: _nameController.text,
                multicastAddress: '230.185.192.108',
                multicastPort: 4000,
                // symmetricKey: base64Decode(joinData['envelope']),
              ),
            ),
          );
        }
      }

      // if (response.statusCode == 200) {
      //   final userId = jsonDecode(response.body)['userId'];

      //   // Gerar assinatura para join
      //   final message = Uint8List.fromList('join-auction'.codeUnits);
      //   final signature = await keyPair.sign(message);

      //   // Join no leilão
      //   final joinResponse = await http.post(
      //     Uri.parse('http://localhost:3000/join'),
      //     headers: {'Content-Type': 'application/json'},
      //     body: jsonEncode({
      //       'userId': userId,
      //       'signature': base64Encode(signature.bytes),
      //     }),
      //   );

      //   if (joinResponse.statusCode == 200) {
      //     final joinData = jsonDecode(joinResponse.body);

      //     if (mounted) {
      //       Navigator.pushReplacement(
      //         context,
      //         MaterialPageRoute(
      //           builder: (context) => AuctionScreen(
      //             userId: userId,
      //             multicastAddress: joinData['multicastAddress'],
      //             multicastPort: joinData['multicastPort'],
      //             symmetricKey: base64Decode(joinData['envelope']),
      //           ),
      //         ),
      //       );
      //     }
      //   }
      // }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : joinLeilao,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class AuctionScreen extends StatefulWidget {
  final String userId;
  final String multicastAddress;
  final int multicastPort;
  // final Uint8List symmetricKey;

  const AuctionScreen({
    super.key,
    required this.userId,
    required this.multicastAddress,
    required this.multicastPort,
    // required this.symmetricKey,
  });

  @override
  State<AuctionScreen> createState() => _AuctionScreenState();
}

class _AuctionScreenState extends State<AuctionScreen> {
  UDP? _multicastSender;
  final _bidController = TextEditingController();
  LeilaoItem? _currentLeilao;
  MDnsClient? client;
  late Endpoint multicastEndpoint;

  @override
  void initState() {
    super.initState();
    _setupMulticast();
  }

  Future<void> _setupMulticast() async {
    multicastEndpoint = Endpoint.multicast(InternetAddress(widget.multicastAddress));

    var receiver = await UDP.bind(multicastEndpoint);

    _multicastSender = await UDP.bind(Endpoint.any());

    receiver.asStream().listen((datagram) {
      if (datagram == null) return;

      try {
        var message = MulticastAction.fromJson(jsonDecode(utf8.decode(datagram.data)));

        if (message.action == 'AUCTION_STATUS') {
          final itemLeilaoAtual = message.data as LeilaoItem?;

          setState(() => _currentLeilao = itemLeilaoAtual);
        }
      } catch (e) {
        print('Error processing message: $e');
      }
    });
    // _multicastSocket = await UDP.bind(Endpoint.multicast(InternetAddress(widget.multicastAddress), port: Port(widget.multicastPort)));

    // var multicastEndpoint = Endpoint.multicast(InternetAddress(widget.multicastAddress), port: Port.any);
    // _multicastSocket = await UDP.bind(multicastEndpoint);

    // _multicastSocket!.socket!.broadcastEnabled = true;
    // _multicastSocket!.socket!.multicastHops = 4;

    // var remoteEndpoint = InternetAddress(widget.multicastAddress);

    // // _multicastSocket!.socket!.joinMulticast(remoteEndpoint);

    // // Listen for updates
    // _multicastSocket!.asStream().listen((datagram) {
    //   if (datagram == null) return;

    //   try {
    //     var message = utf8.decode(datagram.data);

    //     final itemLeilaoAtual = MulticastAction.fromJson(jsonDecode(message)).data as LeilaoItem?;

    //     setState(() => _currentLeilao = itemLeilaoAtual);
    //   } catch (e) {
    //     print('Error processing message: $e');
    //   }
    // });

    // await _multicastSocket!.send(
    //   utf8.encode(
    //     jsonEncode(
    //       MulticastAction(
    //         data: null,
    //         action: 'JOIN',
    //       ).toJson(),
    //     ),
    //   ),
    //   Endpoint.multicast(remoteEndpoint, port: Port(widget.multicastPort)),
    // );
  }

  String _decryptMessage(Uint8List encrypted, Uint8List iv) {
    // Implementação da decriptação AES
    // Usar uma biblioteca como 'encrypt' para implementar
    return ''; // Implementar decriptação real
  }

  Future<void> _enviarLance() async {
    // if (_bidController.text.isEmpty) return;

    // final amount = double.tryParse(_bidController.text);
    // if (amount == null) return;
    const double amount = 110;

    // final encrypted = _encryptMessage(jsonEncode(bid));
    var message = jsonEncode(MulticastAction(data: amount, action: 'BID').toJson());
    var messageBytes = utf8.encode(message);
    await _multicastSender?.send(
      messageBytes,
      Endpoint.multicast(InternetAddress('127.0.0.1'), port: Port(27010)),
    );

    _bidController.clear();
  }

  Uint8List _encryptMessage(String message) {
    // Implementação da encriptação AES
    // Usar uma biblioteca como 'encrypt' para implementar
    return Uint8List(0); // Implementar encriptação real
  }

  @override
  void dispose() {
    _multicastSender?.close();
    _bidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leilão')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentLeilao != null) ...[
              Text('Item: ${_currentLeilao!.nome}'),
              Text('Lance inicial: R\$ ${_currentLeilao!.lanceInicial}'),
              Text('Lance atual: R\$ ${_currentLeilao!.lanceAtual}'),
              Text('Incremento mínimo: R\$ ${_currentLeilao!.incrementoMinimoLance}'),
              Text('Tempo restante: ${_currentLeilao!.endTime.difference(DateTime.now()).inSeconds} segundos'),
            ],
            const SizedBox(
              height: 20,
            ),
            TextFormField(
              controller: _bidController,
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
          ],
        ),
      ),
    );
  }
}
