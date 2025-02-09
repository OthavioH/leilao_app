// lib/main.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:leilao_app/auction_screen.dart';
import 'package:leilao_app/core/helpers/environment_helper.dart';
import 'dart:convert';

import 'package:leilao_app/core/helpers/rsa_helper.dart';
import 'package:leilao_app/services/encryption_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _serverIPController = TextEditingController(text: EnvironmentHelper.apiUrl);
  bool _isLoading = false;

  Future<void> joinLeilao() async {
    setState(() => _isLoading = true);

    try {
      // Registrar usuário
      final serverIp = _serverIPController.text;
      EnvironmentHelper.apiUrl = serverIp;
      var message = "join-auction";
      var privateKey = EnvironmentHelper.privateKey;
      var signature = EncryptionService.signWithPrivateKey(message, privateKey);
      final response = await http.post(
        Uri.parse('$serverIp/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _nameController.text,
          'signature': signature,
        }),
      );

      if (response.statusCode == 201) {
        final joinData = jsonDecode(response.body);

        var decryptedSymmetricKey = EncryptionService.decryptWithPrivateKey(
          joinData['envelope'],
          RSAHelper.parsePrivateKeyFromPEM(privateKey),
        );

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AuctionScreen(
                userName: _nameController.text,
                multicastAddress: joinData['multicastAddress'],
                multicastPort: joinData['multicastPort'],
                symmetricKey: decryptedSymmetricKey,
              ),
            ),
          );
        }
      } else {
        var json = jsonDecode(response.body) as Map<String,dynamic>;
        throw Exception("${json['error']}");
      }
    } catch (e, stackTrace) {
      log(e.toString(), stackTrace: stackTrace);
      // ignore: use_build_context_synchronously
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
              controller: _serverIPController,
              decoration: const InputDecoration(labelText: 'IP do Servidor'),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : joinLeilao,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                      ),
                    )
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
