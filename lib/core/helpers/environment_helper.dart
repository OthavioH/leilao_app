import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentHelper {
  static String apiUrl = dotenv.get('API_URL', fallback: '127.0.0.1');
  static String privateKey = dotenv.get('PRIVATE_KEY', fallback: '');
}
