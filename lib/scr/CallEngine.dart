import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_incall/flutter_incall.dart';
import 'package:inappcalling/inappcalling.dart';
import 'package:inappcalling/models/CallModel.dart';
import 'package:inappcalling/models/CallerModel.dart';
import 'package:inappcalling/utils/Colors.dart';
import 'package:inappcalling/utils/JsonKeys.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import 'CallScreen.dart';
import 'Config.dart';
import 'NotificationService.dart';
import 'PickUpScreen.dart';

bool onCall = false;

class CallEngine {
  CallModel callModel;
  CallerModel receiver;
  CallerModel caller;
  bool isVideoCall;
  String callId;
  List<StreamSubscription> subs = List();
  static CallEngine get instance => CallEngine();
  BuildContext context;

  IncallManager callManager = new IncallManager();
  VideoPlayerController beepController;

  Config config;

  initCallEngine(BuildContext context, CallerModel caller,
      {@required callBack, Config config}) {
    this.context = context;
    this.config = config;
    Firestore.instance;
    var sub = Firestore.instance
        .collection(CALLS_IDS_BASE)
        .where(PARTIES, arrayContains: caller.userId)
        .snapshots()
        .listen((shots) {
      for (var changes in shots.documentChanges) {
        callModel = CallModel.fromDocument(changes.document);
        final status = callModel.status;
        bool callDeclined = status == CallStatus.DECLINED;
        bool callAnswered = status == CallStatus.ACCEPTED;
        bool myItem = callModel.callParties[0] == caller.userId;

        if (changes.type == DocumentChangeType.removed) {
          if (!myItem) hangUpController.add(true);
          callModel = null;
          receiver = null;
          onCall = false;
          return;
        }

        if (callDeclined && !myItem) continue;
        if (callDeclined && myItem) {
          callModel.deleteItem();
          callModel = null;
          receiver = null;
          onCall = false;
          hangUpController.add(true);
          continue;
        }
        if (callAnswered && myItem) callAnsweredController.add(true);
        if (myItem) continue;
//        String callId = callModel.getObjectId();
//        if (userModel.getList(BLOCKED).contains(callId)) continue;
        String otherPersonId = getOtherPersonId(callModel);
        pushAndResult(
          context,
          PickUpScreen(
            config: config,
            call: callModel,
            caller: callModel.caller,
            isVideoCall: callModel.type == CallType.VIDEO,
          ),
        );
      }
//      callsSetup = true;
      if (null != callBack) callBack();
    });
    subs.add(sub);
  }

  disposeCallEngine() {
    beepController.dispose();
    callManager.stop();
    for (var s in subs) s?.cancel();
  }

  endCall() {}

  rejectCall() {}

  pickCall() {}

  placeCall({
    @required CallerModel callerModel,
    @required CallType callType,
    Function onCallPlaced,
  }) {
    callId = getRandomId();
//    Map data = Map();
//    data[TYPE] = PUSH_TYPE_INCOMING_CALL;
//    data[OBJECT_ID] = callId;
//    data[TITLE] = getFullName(userModel);
//    data[MESSAGE] = "Incoming Call";
//    data[CALL_MODE] = callType;
//    final notification = NotificationModel(
//        callId: callId,
//        message: null,
//        callMode: null,
//        type: null,
//        callType: "Incoming Call");

    bool deviceIsIOS = callerModel.callingFrom == CallingFrom.IOS;

    if (deviceIsIOS)
      pushCallIOS(callerModel.apnToken);
    else
      NotificationService.sendPush(
        token: callerModel.fcmToken,
        title: callerModel.displayName,
        body: "Incoming Call",
        tag: '${callId}chat',
        //data: data
      );

    //callModel
    callModel = CallModel(
        type: callType,
        status: CallStatus.RINGING,
        objectId: callId,
        callStatus: null,
        callMode: null,
        callParties: [caller.userId, receiver.userId],
        caller: caller);
    callModel.saveItem();
    if (null != onCallPlaced) onCallPlaced();
    pushAndResult(
        context,
        CallScreen(
          caller: callerModel,
          call: callModel,
          isVideoCall: callType == CallType.VIDEO,
        ));
  }

  pushCallIOS(String apnToken) async {
    Dio().post("https://us-central1-convasapp.cloudfunctions.net/makeCall",
        data: {
          "data": {"callToken": apnToken}
        }).then((response) {
      logInfo("Call has been pushed on IOS");
    }).catchError((e) {
      print(e);
      logInfo("$e");
    });
  }

  getOtherPersonId(CallModel call) {
    List parties = call.callParties;
    parties.remove(caller.userId);
    if (parties.isEmpty) return "";
    return parties[0];
  }

  loadOtherPerson(String uId, chatMode,
      {@required Function(CallerModel receiver) callBack}) async {
    if (uId.isEmpty) return;
    final doc =
        await Firestore.instance.collection(USER_BASE).document(uId).get();
    if (doc == null) return;
    if (!doc.exists) return;
    callBack(CallerModel.fromDocument(doc));
  }
}

logInfo(String info) {
  print("<<< $info >>>");
}

String getRandomId() {
  var uuid = new Uuid();
  return uuid.v1();
}

pushAndResult(context, item, {result}) {
  PageRoute route = PageRouteBuilder(
      transitionsBuilder: transition,
      opaque: false,
      pageBuilder: (context, _, __) {
        return item;
      });
  Navigator.push(context, route).then((_) {
    if (_ != null) {
      if (null != result) result(_);
    }
  });
}

pushReplaceAndResult(context, item,
    {result, opaque = true, bool depend = true}) {
  PageRoute route = PageRouteBuilder(
      transitionsBuilder: transition,
      opaque: false,
      pageBuilder: (context, _, __) {
        return item;
      });
  Navigator.pushReplacement(context, route).then((_) {
    if (_ != null) {
      if (null != result) result(_);
    }
  });
}

Widget transition(BuildContext context, Animation<double> animation,
    Animation<double> secondaryAnimation, Widget child) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
}

textStyle(bool bold, double size, color,
    {underlined = false, bool withShadow = false, bool love = false}) {
  return TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      // fontWeight:bold?FontWeight.bold: null,//FontWeight.normal,
      fontFamily: bold ? "BalooM" : "BalooM",
      fontSize: size,
      shadows: !withShadow
          ? null
          : (<Shadow>[
              Shadow(offset: Offset(4.0, 4.0), blurRadius: 6.0, color: black),
            ]),
      //decorationThickness: 3,
      decoration: underlined ? TextDecoration.underline : TextDecoration.none);
}

SizedBox addSpace(double size) {
  return SizedBox(
    height: size,
  );
}

addSpaceWidth(double size) {
  return SizedBox(
    width: size,
  );
}

Future<File> loadFile(String path, String name) async {
  final ByteData data = await rootBundle.load(path);
  Directory tempDir = await getTemporaryDirectory();
  File tempFile = File('${tempDir.path}/$name');
  await tempFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return tempFile;
}
