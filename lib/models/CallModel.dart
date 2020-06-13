import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:inappcalling/models/CallerModel.dart';
import 'package:inappcalling/utils/JsonKeys.dart';

enum CallType { VOICE, VIDEO }

enum CallStatus { RINGING, ACCEPTED, DECLINED }

class CallModel {
  final String objectId;
  final String callStatus;
  final String callMode;
  final CallType type;
  final CallStatus status;
  final List<String> callParties;
  final CallerModel caller;
  //final CallerModel reciever;

  CallModel({
    @required this.objectId,
    @required this.callStatus,
    @required this.callMode,
    @required this.callParties,
    @required this.type,
    @required this.status,
    @required this.caller,
    //@required this.reciever,
  });

  static Map<String, Object> items = new Map();

  Map toPayLoad() {
    items = {
      'objectId': this.objectId,
      'callStatus': this.callStatus,
      'callMode': this.callMode,
      'callParties': this.callParties,
      'status': _statusInt(),
      'type': _typeInt(),
      'caller': this.caller.toPayLoad(),
      //'reciever': this.reciever.toPayLoad(),
    };
    return items;
  }

  int _statusInt() {
    return status == CallStatus.RINGING
        ? 0
        : status == CallStatus.ACCEPTED ? 1 : 2;
  }

  static CallStatus _intStatus(int p) {
    return p == 0
        ? CallStatus.RINGING
        : p == 1 ? CallStatus.ACCEPTED : CallStatus.DECLINED;
  }

  int _typeInt() {
    return type == CallType.VIDEO ? 0 : 1;
  }

  static CallType _intType(int p) {
    return p == 0 ? CallType.VIDEO : CallType.VIDEO;
  }

  static CallModel fromDocument(DocumentSnapshot shot) {
    final call = CallModel(
      objectId: shot.data['objectId'],
      callStatus: shot.data['callStatus'],
      callMode: shot.data['callMode'],
      callParties: shot.data['callParties'],
      status: _intStatus(shot.data['status']),
      type: _intType(shot.data['type']),
      caller: CallerModel.fromPayload(shot.data['caller']),
      //reciever: CallerModel.fromPayload(shot.data['reciever']),
    );
    items = call.toPayLoad();
    return call;
  }

  saveItem() {
    Firestore.instance
        .collection(CALLS_IDS_BASE)
        .document(objectId)
        .setData(toPayLoad());
  }

  put(String key, String value) {
    //final items = toPayLoad();
    items[key] = value;
  }

  updateItems() {
    Firestore.instance
        .collection(CALLS_IDS_BASE)
        .document(objectId)
        .setData(items);
  }

  deleteItem() {
    Firestore.instance.collection(CALLS_IDS_BASE).document(objectId).delete();
  }
}
