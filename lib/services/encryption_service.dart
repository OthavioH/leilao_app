import 'package:encrypt/encrypt.dart';
import 'package:leilao_app/core/helpers/rsa_helper.dart';
import 'package:pointycastle/asymmetric/api.dart';

class EncryptionService {
  static String signWithPrivateKey(String text, String privateKeyBase64) {
   //Generate a digital signature
    final privateKey = RSAHelper.parsePrivateKeyFromPEM(privateKeyBase64);
    final signer = Signer(RSASigner(RSASignDigest.SHA256, privateKey: privateKey));
    final signature = signer.sign(text);

    return signature.base64;
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