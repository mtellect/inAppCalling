import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:animated_widgets/widgets/rotation_animated.dart';
import 'package:animated_widgets/widgets/shake_animated_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_incall/flutter_incall.dart';
import 'package:inappcalling/inappcalling.dart';
import 'package:inappcalling/models/CallModel.dart';
import 'package:inappcalling/models/CallerModel.dart';
import 'package:inappcalling/scr/Config.dart';
import 'package:inappcalling/utils/Colors.dart';
import 'package:inappcalling/utils/JsonKeys.dart';

import 'AppPermissions.dart';
import 'CallEngine.dart';
import 'CallScreen.dart';

class PickUpScreen extends StatefulWidget {
  final bool isVideoCall;
  final CallModel call;
  final CallerModel caller;
  final Config config;
  const PickUpScreen({
    this.isVideoCall = false,
    this.call,
    this.caller,
    this.config,
  });

  @override
  _PickUpScreenState createState() => _PickUpScreenState();
}

class _PickUpScreenState extends State<PickUpScreen> {
  static final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  bool isVideoCall = false;
  static const APP_ID = "40c37c3e06f840449394b70b93b177d5";
  CallModel call;
  CallerModel caller;
  bool callAnswered = false;

  IncallManager callManager = new IncallManager();
  List<StreamSubscription> subs = [];

  @override
  void dispose() {
    _users.clear();
    for (var sub in subs) sub?.cancel();
    callManager.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    call = widget.call;
    caller = widget.caller;
    isVideoCall = widget.isVideoCall;
    setState(() {});
    startRinging();
    listenToUser();
    initialize();
  }

  startRinging() {
    callManager.startRingback();
    //callManager.startRingtone(RingtoneUriType.DEFAULT, 'default', 30);
    var callSubs = hangUpController.stream.listen((bool p) {
      if (p) onCallDeclined();
    });
    subs.add(callSubs);
  }

  void onCallDeclined() {
    callManager.stopRingback();
    CallModel callUpdate = CallModel(
        objectId: call.objectId,
        callStatus: null,
        callMode: call.callMode,
        callParties: call.callParties,
        type: call.type,
        status: CallStatus.DECLINED,
        caller: call.caller);
    callUpdate.saveItem();
    Future.delayed(Duration(milliseconds: 15), () {
      Navigator.pop(context);
    });
  }

  void onCallAnswered() async {
    bool granted = await AppPermissions.cameraAndMicrophonePermissionsGranted();
    if (!granted) return;
    callManager.stopRingback();
    CallModel callUpdate = CallModel(
        objectId: call.objectId,
        callStatus: null,
        callMode: call.callMode,
        callParties: call.callParties,
        type: call.type,
        status: CallStatus.ACCEPTED,
        caller: call.caller);
    callUpdate.saveItem();
    Future.delayed(Duration(milliseconds: 10), () {
      pushReplaceAndResult(
          context,
          CallScreen(
            caller: caller,
            call: call,
            isVideoCall: isVideoCall,
          ),
          depend: false);
    });
  }

  listenToUser() async {
    var sub = Firestore.instance
        .collection(USER_BASE)
        .document(widget.caller.userId)
        .snapshots()
        .listen((doc) {
      caller = CallerModel.fromDocument(doc);
      setState(() {});
    });
    subs.add(sub);
  }

  initialize() async {
    if (APP_ID.isEmpty) {
      setState(() {
        _infoStrings.add(
          'APP_ID missing, please provide your APP_ID in settings.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }

    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();
    await AgoraRtcEngine.enableWebSdkInteroperability(true);
    await AgoraRtcEngine.setParameters(
        '''{\"che.video.lowBitRateStreamParameter\":{\"width\":320,\"height\":180,\"frameRate\":15,\"bitRate\":140}}''');
    //await AgoraRtcEngine.joinChannel(null, callId, null, 0);
  }

  /// Create agora sdk instance and initialize
  _initAgoraRtcEngine() async {
    await AgoraRtcEngine.create(APP_ID);
    await AgoraRtcEngine.enableAudio();
    if (isVideoCall) await AgoraRtcEngine.enableVideo();
  }

  /// Add agora event handlers
  _addAgoraEventHandlers() {
    AgoraRtcEngine.onError = (dynamic code) {
      setState(() {
        final info = 'onError: $code';
        _infoStrings.add(info);
      });
    };

    AgoraRtcEngine.onJoinChannelSuccess = (
      String channel,
      int uid,
      int elapsed,
    ) {
      setState(() {
        final info = 'onJoinChannel: $channel, uid: $uid';
        _infoStrings.add(info);
      });
    };

    AgoraRtcEngine.onLeaveChannel = () {
      setState(() {
        _infoStrings.add('onLeaveChannel');
        _users.clear();
      });
    };

    AgoraRtcEngine.onUserJoined = (int uid, int elapsed) {
      setState(() {
        final info = 'userJoined: $uid';
        _infoStrings.add(info);
        _users.add(uid);
      });
    };

    AgoraRtcEngine.onUserOffline = (int uid, int reason) {
      setState(() {
        final info = 'userOffline: $uid';
        _infoStrings.add(info);
        _users.remove(uid);
      });
    };

    AgoraRtcEngine.onFirstRemoteVideoFrame = (
      int uid,
      int width,
      int height,
      int elapsed,
    ) {
      setState(() {
        final info = 'firstRemoteVideo: $uid ${width}x $height';
        _infoStrings.add(info);
      });
    };
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    final List<AgoraRenderWidget> list = [
      AgoraRenderWidget(0, local: true, preview: true),
    ];
    _users.forEach((int uid) => list.add(AgoraRenderWidget(uid)));
    return list;
  }

  /// Video view wrapper
  Widget _videoView(view) {
    return Expanded(child: Container(child: view));
  }

  /// Video view row wrapper
  Widget _expandedVideoRow(List<Widget> views) {
    final wrappedViews = views.map<Widget>(_videoView).toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Video layout wrapper
  Widget videoPanel() {
    final views = _getRenderViews();
    switch (views.length) {
      case 1:
        return Container(
            child: Column(
          children: <Widget>[_videoView(views[0])],
        ));
      case 2:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow([views[0]]),
            _expandedVideoRow([views[1]])
          ],
        ));
      case 3:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, 3))
          ],
        ));
      case 4:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, 4))
          ],
        ));
      default:
    }
    return Container();
  }

  /// Toolbar layout
  Widget toolPanel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.all(15),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: white.withOpacity(.09),
            borderRadius: BorderRadius.circular(15)),
        child: Row(
          //mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(2, (p) {
            var icon = Icons.call;
            Color bgColor = green;

            if (p == 1) {
              icon = Icons.call_end;
              bgColor = red;
            }

            return Flexible(
              child: ShakeAnimatedWidget(
                enabled: p == 0,
                duration: Duration(milliseconds: 1500),
                shakeAngle: Rotation.deg(
                  z: 40,
                ),
                curve: Curves.linear,
                child: Container(
                  margin: EdgeInsets.all(5),
                  height: 80,
                  width: 80,
                  child: MaterialButton(
                    onPressed: () {
                      if (p == 0) onCallAnswered();
                      if (p == 1) onCallDeclined();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: white,
                        size: 30,
                      ),
                    ),
                    color: bgColor,
                    padding: EdgeInsets.all(0),
                    shape: CircleBorder(),
//                    shape: RoundedRectangleBorder(
//                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Info panel to show logs
  Widget infoPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: ListView.builder(
            reverse: true,
            itemCount: _infoStrings.length,
            itemBuilder: (BuildContext context, int index) {
              if (_infoStrings.isEmpty) {
                return null;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _infoStrings[index],
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Profile Panel of the other user
  Widget profilePanel() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        //alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              //mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  widget.config.appIcon,
                  height: 30,
                  width: 30,
                  fit: BoxFit.cover,
                ),
                addSpaceWidth(10),
                Text(
                  '${widget.config.appTitle.toUpperCase()} VOICE CALL',
                  style: textStyle(false, 14, white.withOpacity(.7)),
                ),
              ],
            ),
            addSpace(5),
            userImageItem(context, caller, size: 80, strokeSize: 1),
            addSpace(10),
            Text(
              caller.displayName,
              style: textStyle(true, 25, white),
            ),
            //addSpace(5),
            Text(
              "INCOMING CALL",
              style: textStyle(false, 16, white.withOpacity(.7)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: Stack(
        children: <Widget>[
          if (isVideoCall)
            videoPanel()
          else
            Container(
              color: widget.config.appColor,
            ),
          //infoPanel(),
          toolPanel(),
          profilePanel()
        ],
      ),
    );
  }

  userImageItem(context, CallerModel caller,
      {double size = 40, double strokeSize = 4, bool padLeft = true}) {
    return new GestureDetector(
      onTap: () {},
      child: new AnimatedContainer(
        duration: Duration(milliseconds: 500),
        decoration: BoxDecoration(
          border: Border.all(width: strokeSize, color: white),
          shape: BoxShape.circle,
        ),
        margin: EdgeInsets.fromLTRB(padLeft ? 10 : 0, 0, 0, 0),
        width: size,
        height: size,
        child: Stack(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(size / 2),
              child: Container(
//                width: size,
                height: size,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.config.appColor,
                    gradient: LinearGradient(colors: [
                      orange01,
                      orange04,
                    ])),
                child: CachedNetworkImage(
                  imageUrl: caller.displayPhoto,
                  fit: BoxFit.cover,
                  height: size,
                  width: size,
                ),
              ),
            ),
//            if (isOnline(caller) && !caller.myItem())
//              Container(
//                width: 10,
//                height: 10,
//                decoration: BoxDecoration(
//                  shape: BoxShape.circle,
//                  border: Border.all(color: white, width: 2),
//                  color: red0,
//                ),
//              ),
          ],
        ),
      ),
    );
  }
}
