import 'dart:convert';

import 'package:crypto/crypto.dart';

String stremioCacheKey(String namespace, String identity) {
  final digest = md5.convert(utf8.encode(identity));
  return '${namespace}_$digest';
}
