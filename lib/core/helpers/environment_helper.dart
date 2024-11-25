import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentHelper {
  static get apiUrl => dotenv.get('API_URL', fallback: 'No API_URL');
  static get apiIP => dotenv.get('API_IP', fallback: '127.0.0.1');
}
