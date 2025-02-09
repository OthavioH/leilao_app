import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentHelper {
  static String apiUrl = dotenv.get('API_URL', fallback: '127.0.0.1');
  static String get privateKey {
    var key = dotenv.get('PRIVATE_KEY', fallback: '');
    // remove "BEGIN PRIVATE KEY" "\n" and "END PRIVATE KEY"
    // key = key.replaceAll(RegExp(r'-----[A-Z ]+-----'), '');
    // key = key.replaceAll(r'\n', '\n');
    return key;
  }
}
