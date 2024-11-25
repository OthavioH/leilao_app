import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:leilao_app/test.dart';

void logNetworkInterfaces() {
  NetworkInterface.list().then((interfaces) {
    for (var interface in interfaces) {
      print('Interface: ${interface.name}');
      for (var address in interface.addresses) {
        print('  Address: ${address.address}');
      }
    }
  });
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logNetworkInterfaces();
  await dotenv.load(fileName: ".env");
  runApp(const AuctionApp());
}

class AuctionApp extends StatelessWidget {
  const AuctionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auction Client',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
