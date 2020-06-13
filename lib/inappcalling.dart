import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:inappcalling/models/CallerModel.dart';
import 'package:inappcalling/scr/CallEngine.dart';

import 'scr/Config.dart';

final hangUpController = StreamController<bool>.broadcast();
final callAnsweredController = StreamController<bool>.broadcast();

class InAppCalling {
  static InAppCalling get instance => InAppCalling();
  static CallEngine _callEngine;

  static const MethodChannel _channel = const MethodChannel('inappcalling');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static initializeInAppCalling(
      {@required String agoraId,
      @required BuildContext context,
      @required CallerModel caller,
      @required Function(CallEngine engine) onCallEngineReady,
      Config config}) {
    _callEngine.initCallEngine(context, caller,
        config: config, callBack: onCallEngineReady);
  }

  static dispose() {
    _callEngine.disposeCallEngine();
  }
}
