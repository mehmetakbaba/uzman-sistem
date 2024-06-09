import 'package:bulutbilisim/firebase_options.dart';
import 'package:bulutbilisim/homePage.dart';
import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
late List<CameraDescription> cameras;
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  cameras =  await availableCameras();
  runApp(const HomePage());
}

