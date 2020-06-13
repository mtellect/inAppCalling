import 'package:flutter/material.dart';

class Config {
  final String appTitle;
  final String appIcon;
  final Color appColor;

  Config(
      {this.appTitle = "InaAppCall",
      this.appIcon = "assets/ic_launcher.png",
      this.appColor = Colors.blue});
}
