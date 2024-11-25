import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentHelper {
  static get apiUrl => dotenv.get('API_URL', fallback: 'No API_URL');
}
