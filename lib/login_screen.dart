// lib/main.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:leilao_app/auction_screen.dart';
import 'package:leilao_app/core/helpers/environment_helper.dart';
import 'dart:convert';

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
                userName: _nameController.text,
                multicastAddress: joinData['multicastAddress'],
                multicastPort: joinData['multicastPort'],
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
            const Text(
              'Leilão atual',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
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
