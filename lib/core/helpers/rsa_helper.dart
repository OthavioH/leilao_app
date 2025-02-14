import 'dart:convert';

import 'package:asn1lib/asn1lib.dart';
import 'package:pointycastle/asymmetric/api.dart';

class RSAHelper {
  // Parse PEM string to RSAPrivateKey
  static RSAPrivateKey parsePrivateKeyFromPEM(String pemString) {
    // Remove header, footer, and newlines
    final pemContent = pemString.replaceAll('-----BEGIN RSA PRIVATE KEY-----', '').replaceAll('-----END RSA PRIVATE KEY-----', '').replaceAll('\n', '');

    // Decode base64
    final bytes = base64.decode(pemContent);

    // Parse ASN1 sequence
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Get the elements we need
    final modulus = topLevelSeq.elements[1] as ASN1Integer;
    final privateExponent = topLevelSeq.elements[3] as ASN1Integer;
    final p = topLevelSeq.elements[4] as ASN1Integer;
    final q = topLevelSeq.elements[5] as ASN1Integer;

    return RSAPrivateKey(
      modulus.valueAsBigInteger,
      privateExponent.valueAsBigInteger,
      p.valueAsBigInteger,
      q.valueAsBigInteger,
    );
  }

  /// Parse PEM string to RSAPublicKey
  static RSAPublicKey parsePublicKeyFromPEM(String pemString) {
    // Remove header, footer, and newlines
    final pemContent = pemString.replaceAll('-----BEGIN PUBLIC KEY-----', '').replaceAll('-----END PUBLIC KEY-----', '').replaceAll('\n', '');

    // Decode base64
    final bytes = base64.decode(pemContent);

    // Parse ASN1 sequence
    final asn1Parser = ASN1Parser(bytes);
    final topLevelSeq = asn1Parser.nextObject() as ASN1Sequence;

    // Get the bit string
    final bitString = topLevelSeq.elements[1] as ASN1BitString;

    // Parse the bit string to get the actual public key sequence
    final publicKeySeq = ASN1Parser(bitString.contentBytes()).nextObject() as ASN1Sequence;

    // Get the elements we need
    final modulus = publicKeySeq.elements[0] as ASN1Integer;
    final exponent = publicKeySeq.elements[1] as ASN1Integer;

    return RSAPublicKey(modulus.valueAsBigInteger, exponent.valueAsBigInteger);
  }
}
