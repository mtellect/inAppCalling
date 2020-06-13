import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:animated_widgets/animated_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:inappcalling/inappcalling.dart';
import 'package:inappcalling/models/CallModel.dart';
import 'package:inappcalling/models/CallerModel.dart';
import 'package:inappcalling/utils/Colors.dart';
import 'package:inappcalling/utils/JsonKeys.dart';
import 'package:video_player/video_player.dart';

import 'CallEngine.dart';
import 'Config.dart';

class CallScreen extends StatefulWidget {
  final bool isVideoCall;
  final CallModel call;
  final CallerModel caller;
  final Config config;
  const CallScreen({
    this.isVideoCall = false,
    @required this.call,
    @required this.caller,
    this.config,
  });

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  static final _users = <int>[];
  final _infoStrings = <String>[];
  bool muted = false;
  bool isVideoCall = false;
  static const APP_ID = "40c37c3e06f840449394b70b93b177d5";

  String callId = getRandomId();
  CallModel call;
  CallerModel caller;
  bool callAnswered = false;
  VideoPlayerController beepController;
  List<StreamSubscription> subs = [];
  bool hideViews = false;

  @override
  void dispose() {
    _users.clear();
    AgoraRtcEngine.leaveChannel();
    AgoraRtcEngine.destroy();
    for (var sub in subs) sub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    call = widget.call;
    caller = widget.caller;
    isVideoCall = widget.isVideoCall;
    callId = widget.call.objectId;
    setState(() {});
    var hangUp = hangUpController.stream.listen((bool p) {
      if (p) hangUpCall();
    });
    var callAnswered = callAnsweredController.stream.listen((bool p) {
      if (p) {
        this.callAnswered = true;
        //autoHidePanels();
        setState(() {});
      }
    });
    subs.add(hangUp);
    subs.add(callAnswered);
    initialize();
    setUpBeep();
    listenToUser();
  }

  void hangUpCall() {
    beepController?.pause();
    beepController = null;
    beepController?.dispose();
//    if (call.myItem()) {
//      call.deleteItem();
//    } else {
//      call
//        ..put(STATUS, CALL_STATUS_DECLINED)
//        ..updateItems();
//    }
    bool myItem = call.callParties[0] == caller.userId;
    if (myItem) {
      call.deleteItem();
    } else {
      CallModel callUpdate = CallModel(
          objectId: call.objectId,
          callStatus: null,
          callMode: call.callMode,
          callParties: call.callParties,
          type: call.type,
          status: CallStatus.DECLINED,
          caller: call.caller);
      callUpdate.saveItem();
    }
    Navigator.pop(context);
  }

  void autoHidePanels({int delay = 2}) {
    Future.delayed(Duration(seconds: delay), () {
      hideViews = true;
      setState(() {});
    });
  }

  setUpBeep() async {
    bool myItem = call.callParties[0] == caller.userId;

    if (!mounted) return;
    if (callAnswered) return;
    if (myItem) return;
    File beep = await loadFile('assets/sounds/beep.wav', "beep.wav");
    beepController = VideoPlayerController.file(beep);
    beepController.initialize().then((value) {
      beepController.play();
      //beepController.setLooping(true);
      Future.delayed(Duration(seconds: 2), () {
        beepController = null;
        setUpBeep();
      });
    });
  }

  keepBeeping() {
    if (!mounted) return;
    if (null == beepController) return;

    Future.delayed(Duration(seconds: 4), () {
      beepController.pause();
      Future.delayed(Duration(seconds: 4), () {
        beepController?.play();
        keepBeeping();
      });
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
    await AgoraRtcEngine.joinChannel(null, callId, null, 0);
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

  void onCallAnswered() {
    setState(() {
      callAnswered = !callAnswered;
    });
    initialize();
  }

  void onCallEnd() {
    Navigator.pop(context);
  }

  void onToggleMute() {
    setState(() {
      muted = !muted;
    });
    AgoraRtcEngine.muteLocalAudioStream(muted);
  }

  void onSwitchCamera() {
    AgoraRtcEngine.switchCamera();
  }

  void onSwitchCall() {
    if (isVideoCall) {
      AgoraRtcEngine.disableVideo();
    } else {
      AgoraRtcEngine.enableVideo();
    }
    isVideoCall = !isVideoCall;
    setState(() {});
  }

  void onCallRequest() {
    //calling ? onCallEnd() : onCallAnswered();
    hangUpCall();
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
    print(views.length);

    return Stack(
      children: [
        if (views.length == 1) views[0] else views[1],
        if (views.length > 1)
          Positioned(
              bottom: 100,
              right: 15,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 150,
                  width: 100,
                  child: views[0],
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: white, width: 2)),
                ),
              ))
      ],
    );

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
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (p) {
            var icon = Icons.call_end;
            Color bgColor = red;
            Color iconColor = white;

            if (p == 0) {
              icon = muted ? Icons.mic_off : Icons.mic;
              bgColor = white;
              iconColor = black;
            }

            if (p == 1) {
              icon = Icons.chat;
              bgColor = white;
              iconColor = black;
            }

            if (p == 3) {
              icon = isVideoCall ? Icons.videocam_off : Icons.videocam;
              bgColor = white;
              iconColor = black;
            }
            if (p == 4) {
              icon = Icons.switch_camera;
              bgColor = white;
              iconColor = black;
            }
            return Flexible(
              child: ShakeAnimatedWidget(
                enabled: false,
                duration: Duration(milliseconds: 1500),
                shakeAngle: Rotation.deg(
                  z: 40,
                ),
                curve: Curves.linear,
                child: Container(
                  margin: EdgeInsets.all(5),
                  height: 60,
                  width: 60,
                  child: MaterialButton(
                    onPressed: () {
                      if (p == 0) onToggleMute();
                      //if (p == 1) onCallEnd(context);
                      if (p == 2) onCallRequest();
                      if (p == 3) onSwitchCall();
                      if (p == 4) onSwitchCamera();
                    },
                    child: Container(
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        color: iconColor,
                      ),
                    ),
                    color: bgColor,
                    padding: EdgeInsets.all(0),
                    //materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
//            Text(
//              callAnswered || !call.myItem()
//                  ? "On a Call"
//                  : caller.getBoolean(IS_ONLINE) ? 'RINGING' : 'CALLING',
//              style: textStyle(false, 16, white.withOpacity(.7)),
//            )
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
          GestureDetector(
            onTap: () {
              if (!callAnswered) return;
              hideViews = false;
              setState(() {});
              autoHidePanels();
            },
            child: Container(
              color: transparent,
            ),
          ),

//          if (hideViews) ...[toolPanel(), profilePanel()]
          ...[toolPanel(), profilePanel()]
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
