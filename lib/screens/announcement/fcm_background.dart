import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NO UI WORK HERE
  // Just logging or silent processing
  print('BG Message: ${message.data}');
}
