import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:leilao_app/login_screen.dart';

void logNetworkInterfaces() {
  if (kIsWeb) return;
  NetworkInterface.list().then((interfaces) {
    for (var interface in interfaces) {
      log('Interface: ${interface.name}');
      for (var address in interface.addresses) {
        log('  Address: ${address.address}');
      }
    }
  });
}

final navigatorKey = GlobalKey<NavigatorState>();

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
      navigatorKey: navigatorKey,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.dark,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
