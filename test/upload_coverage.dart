import 'dart:async';
import 'dart:io';
import 'package:coveralls/coveralls.dart';

Future<void> main() async {
  try {
    final coverage = File('coverage/coverage.lcov');
    await Client().upload(await coverage.readAsString());
    print('Code coverage report uploaded to coveralls.io');
  } on Exception catch (err) {
    print('An error occurred: $err');
    if (err is ClientException) print('From: ${err.uri}');
  }
}
