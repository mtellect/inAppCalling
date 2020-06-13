import 'dart:convert';

import 'package:http/http.dart';

class NotificationService {
  static final Client client = Client();

  static const String serverKey =
      "AAAAGH17B_U:APA91bEzci35Zn84P-mrsSJH2LbPN6Dnc15hyxN4HZl9ZuLvbdIzOn7f6OHFxGGT_na8qd7fn8xTbovU4zXf8WA76FBshlzNszMSVGHipr02H25id7vEHmWn5ZXFC4IwzV97JrZHSo9H";
  static sendPush({
    String topic,
    String token,
    int liveTimeInSeconds = (Duration.secondsPerDay * 7),
    String title,
    String body,
    String image,
    Map data,
    String tag,
  }) async {
    String fcmToken = topic != null ? '/topics/$topic' : token;
    data = data ?? Map();
    data['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';
    data['id'] = '1';
    data['status'] = 'done';
    client.post(
      'https://fcm.googleapis.com/fcm/send',
      body: json.encode({
        'notification': {
          'body': body,
          'title': title,
          'image': image,
          'icon': "ic_notify",
          'color': "#ffffff",
          'tag': tag
        },
        'data': data,
        'to': fcmToken,
        'time_to_live': liveTimeInSeconds
      }),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
    );
  }
}
