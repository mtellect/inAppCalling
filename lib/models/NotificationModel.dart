import 'package:flutter/cupertino.dart';

import 'CallModel.dart';

class NotificationModel {
  final String callId;
  final String message;
  final String callMode;
  final int type;
  final CallType callType;

  NotificationModel({
    @required this.callId,
    @required this.message,
    @required this.callMode,
    @required this.type,
    @required this.callType,
  });

  Map toPayLoad() {
    return {
      'callId': this.callId,
      'message': this.message,
      'callMode': this.callMode,
      'type': this.type,
      'callType': this.callType,
    };
  }

  static NotificationModel fromPayload(Map data) {
    return NotificationModel(
      callId: data['objectId'],
      message: data['callStatus'],
      callMode: data['callMode'],
      type: data['type'],
      callType: data['callType'],
    );
  }

//  saveItem() {
//    Firestore.instance
//        .collection(CALLS_IDS_BASE)
//        .document(callId)
//        .setData(toPayLoad());
//  }

//  deleteItem() {
//    Firestore.instance.collection(CALLS_IDS_BASE).document(callId).delete();
//  }
}
