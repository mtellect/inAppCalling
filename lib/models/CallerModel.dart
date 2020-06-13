import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

enum CallingFrom { ANDROID, IOS }

class CallerModel {
  final String userId;
  final String displayName;
  final String displayPhoto;
  final String fcmToken;
  final String apnToken;
  final CallingFrom callingFrom;

  CallerModel(
      {@required this.userId,
      @required this.displayName,
      @required this.displayPhoto,
      @required this.fcmToken,
      @required this.apnToken,
      @required this.callingFrom});

  Map toPayLoad() {
    return {
      'userId': this.userId,
      'displayName': this.displayName,
      'displayPhoto': this.displayPhoto,
      'fcmToken': this.fcmToken,
      'apnToken': this.apnToken,
      'platform': _platformInt(),
    };
  }

  int _platformInt() {
    return callingFrom == CallingFrom.IOS ? 0 : 1;
  }

  static CallingFrom _intPlatform(int p) {
    return p == 0 ? CallingFrom.IOS : CallingFrom.ANDROID;
  }

  static CallerModel fromDocument(DocumentSnapshot shot) {
    return CallerModel(
        userId: shot.data['userId'],
        displayName: shot.data['displayName'],
        displayPhoto: shot.data['displayPhoto'],
        fcmToken: shot.data['fcmToken'],
        apnToken: shot.data['apnToken'],
        callingFrom: _intPlatform(shot.data['callingFrom']));
  }

  static CallerModel fromPayload(Map data) {
    return CallerModel(
        userId: data['userId'],
        displayName: data['displayName'],
        displayPhoto: data['displayPhoto'],
        fcmToken: data['fcmToken'],
        apnToken: data['apnToken'],
        callingFrom: _intPlatform(data['callingFrom']));
  }
}
