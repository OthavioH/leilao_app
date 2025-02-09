import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';

class EncryptionService {
  static String encryptWithPrivateKey(String text, RSAPrivateKey privateKey) {
    final encrypter = Encrypter(RSA(privateKey: privateKey));
    final encrypted = encrypter.encrypt(text);

    return encrypted.base64;
  }
  
  static String decryptWithPrivateKey(String text, RSAPrivateKey privateKey) {
    final encrypter = Encrypter(RSA(privateKey: privateKey));
    final decrypted = encrypter.decrypt(Encrypted.fromBase64(text));

    return decrypted;
  }

  /// Decrypts a message using a Symmmetric key
  /// 
  /// The message is expected to be in the format `iv:encryptedMessage`
  /// 
  /// This method uses the AES-256-CBC algorithm
  static String decryptWithSymmetricKey(String text, String symmetricKey) {
    final parts = text.split(':');
    final iv = IV.fromBase64(parts[0]);
    final encryptedMessage = parts[1];
    final encrypter = Encrypter(AES(Key.fromBase64(symmetricKey), mode: AESMode.cbc));
    final decrypted = encrypter.decrypt(Encrypted.fromBase64(encryptedMessage), iv: iv);

    return decrypted;
  }

  /// Encrypts a message using a Symmmetric key
  /// 
  /// The message is returned in the format `iv:encryptedMessage`
  /// 
  /// This method uses the AES-256-CBC algorithm
  static String encryptWithSymmetricKey(String text, String symmetricKey) {
    final encrypter = Encrypter(AES(Key.fromBase64(symmetricKey), mode: AESMode.cbc));
    final iv = IV.fromLength(16);
    final encrypted = encrypter.encrypt(text, iv: iv);

    return '${iv.base64}:${encrypted.base64}';
  }
}