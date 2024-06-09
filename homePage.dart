import 'package:bulutbilisim/main.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;
FirebaseStorage firebaseStorage = FirebaseStorage.instance;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isVideo = false;
  String isSmile = 'Ekranda Yüz Yok';
  String collectionPath = 'user1';
  TextEditingController textEditingController = TextEditingController();
  late FaceDetector _faceDetector;
  late CameraController cameraController;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.5,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    initializeCamera();
  }
  Future<void> initializeCamera() async{
    cameraController = CameraController(cameras[1], ResolutionPreset.medium,
        enableAudio: false);
    debugPrint(cameras.toString());
    await cameraController.initialize();
    detecFace();

    if (!mounted) {
      return;
    }

  }
  Future<void> detecFace() async{
    int i = 0;

    if (!cameraController.value.isInitialized) {

      return;
    }
    if(!mounted){
      return;
    }
    cameraController.startImageStream((image) async {
      i++;
      if(i == 30){
        i = 0;
        debugPrint('!');
        final plane = image.planes.first;
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();
        try {

          final inputImage = InputImage.fromBytes(
              bytes: bytes,
              metadata: InputImageMetadata(
                  size: Size(double.parse(image.width.toString()),
                      double.parse(image.height.toString())),
                  rotation: InputImageRotation.rotation270deg,
                  format: InputImageFormat.nv21,
                  bytesPerRow: plane.bytesPerRow));

          final faces = await _faceDetector.processImage(inputImage);
          debugPrint(faces.toString());
          double? scoreMyFace = faces[0].smilingProbability;
          debugPrint(scoreMyFace.toString());
          if(scoreMyFace != null){
            if(scoreMyFace < 0.6){
             setState(() {
               isSmile = 'Üzgün';
             });
            }else{
             setState(() {
               isSmile = 'Mutlu';
             });
            }
          }


        } catch (e) {
          setState(() {
            isSmile = 'Ekranda Yüz Yok';
          });
        }
      }
    });

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 75,
            backgroundColor: Colors.grey,
            centerTitle: true,
            title: Padding(
              padding: const EdgeInsets.only(top: 100, bottom: 100),
              child: SizedBox(
                width: 500,
                height: 100,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: textEditingController,
                        decoration: const InputDecoration(
                          hintText: 'Ara...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide:
                                BorderSide(width: 1, color: Colors.blueAccent),
                          ),
                          hintStyle: TextStyle(color: Colors.black),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (textEditingController.text.isNotEmpty) {
                          setState(() {
                            collectionPath = textEditingController.text;
                          });
                        } else {
                          setState(() {
                            collectionPath = 'user1';
                          });
                        }
                      },
                      icon: const Icon(Icons.search),
                      color: Colors.black,
                    ),
                    IconButton(
                        onPressed: () async {
                          await pickMedia();
                          setState(() {});
                        },
                        icon: const Icon(Icons.image)),
                    TextButton(
                        onPressed: () {
                          isVideo = !isVideo;
                          setState(() {});
                        },
                        child: Text(isVideo ? 'Videos' : 'Pictures'))
                  ],
                ),
              ),
            ),
          ),
          body: Container(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF232526),
                    Color(0xFF414345),
                  ]),
            ),
            child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: FutureBuilder(
                  future: isVideo
                      ? firestore
                          .collection('Users')
                          .doc(collectionPath)
                          .collection('videos')
                          .orderBy('date', descending: true)
                          .get()
                      : firestore
                          .collection('Users')
                          .doc(collectionPath)
                          .collection('pictures')
                          .orderBy('date', descending: true)
                          .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    } else {
                      final items = snapshot.data!.docs;

                      return ListWheelScrollView(
                          itemExtent: 300,
                          diameterRatio: 4,
                          children: items.map((e) {
                            final data = e.data();

                            return isVideo
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      VideoPlayerWidget(
                                        videoUrl: data['url'],
                                        docId: e.id,
                                        isVideo: true,
                                        path: data['path'],
                                      ),
                                      IconButton(
                                          onPressed: () {
                                            launchURL(data['url']);
                                          },
                                          icon: const Icon(Icons.download)),
                                      Visibility(
                                        visible: collectionPath == 'user1'
                                            ? true
                                            : false,
                                        child: IconButton(
                                            onPressed: () {
                                              deleteMedia(data['path'], e.id,
                                                      isVideo)
                                                  .then((_) {
                                                setState(() {});
                                              });
                                            },
                                            icon: const Icon(Icons.delete)),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Text(isSmile,style: TextStyle(color: Colors.white),),
                                      Expanded(
                                        child: Image.network(
                                          data['url'],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                launchURL(data['url']);
                                              },
                                              icon: const Icon(Icons.download),
                                            ),
                                            Visibility(
                                              visible: collectionPath == 'user1'
                                                  ? true
                                                  : false,
                                              child: IconButton(
                                                  onPressed: () {
                                                    deleteMedia(data['path'],
                                                            e.id, isVideo)
                                                        .then((_) {
                                                      setState(() {});
                                                    });
                                                  },
                                                  icon:
                                                      const Icon(Icons.delete)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                          }).toList());
                    }
                  },
                )),
          )),
    );
  }
}

Future<void> pickMedia() async {
  final ImagePicker picker = ImagePicker();
  XFile? media = await picker.pickMedia();
  var temp = await media!.readAsBytes();
  final ref = firebaseStorage.ref();
  if (media.name.substring(media.name.length - 3) == 'mp4') {
    String uniqeName = await uniqeMediaName(true, media.name);
    final videoRef = ref.child('Users/user1/videos/${uniqeName + media.name}');
    await videoRef.putData(temp);
    String downloadURL = await videoRef.getDownloadURL();
    firestore.collection('Users').doc('user1').collection('videos').add({
      'url': downloadURL,
      'date': FieldValue.serverTimestamp(),
      'path': 'Users/user1/videos/${uniqeName + media.name}',
      'name': uniqeName + media.name
    });
  } else {
    String uniqeName = await uniqeMediaName(false, media.name);
    final pictureRef =
        ref.child('Users/user1/pictures/${uniqeName + media.name}');
    await pictureRef.putData(temp);
    String downloadURL = await pictureRef.getDownloadURL();
    firestore.collection('Users').doc('user1').collection('pictures').add({
      'url': downloadURL.toString(),
      'date': FieldValue.serverTimestamp(),
      'path': 'Users/user1/pictures/${uniqeName + media.name}',
      'name': uniqeName + media.name
    });
  }
}

Future<String> uniqeMediaName(bool isMp4, String mediaName) async {
  int counter = 0;
  if (isMp4) {
    QuerySnapshot querySnapshot = await firestore
        .collection('Users/user1/videos')
        .where('name', isEqualTo: mediaName)
        .get();
    if (querySnapshot.size == 0) {
      return '';
    }
    counter++;
    while (true) {
      debugPrint('$counter$mediaName');
      QuerySnapshot querySnapshot = await firestore
          .collection('Users/user1/videos')
          .where('name', isEqualTo: '$counter$mediaName')
          .get();
      if (querySnapshot.size == 0) {
        return counter.toString();
      }
      counter++;
    }
  } else {
    QuerySnapshot querySnapshot = await firestore
        .collection('Users/user1/pictures')
        .where('name', isEqualTo: mediaName)
        .get();
    if (querySnapshot.size == 0) {
      return '';
    }
    counter++;
    while (true) {
      QuerySnapshot querySnapshot = await firestore
          .collection('Users/user1/pictures')
          .where('name', isEqualTo: '$counter$mediaName')
          .get();
      if (querySnapshot.size == 0) {
        return counter.toString();
      }
      counter++;
    }
  }
}

Future<void> launchURL(String strUrl) async {
  Uri url = Uri.parse(strUrl);
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    debugPrint('error: $url');
  }
}

Future<void> deleteMedia(String path, String docId, bool isVideo) async {
  if (isVideo) {
    await firestore
        .collection('Users')
        .doc('user1')
        .collection('videos')
        .doc(docId)
        .delete();
  } else {
    await firestore
        .collection('Users')
        .doc('user1')
        .collection('pictures')
        .doc(docId)
        .delete();
  }

  await firebaseStorage.ref().child(path).delete();
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String path;
  final String docId;
  final bool isVideo;

  const VideoPlayerWidget(
      {required this.videoUrl,
      required this.path,
      required this.docId,
      required this.isVideo});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    Uri url = Uri.parse(widget.videoUrl);
    _controller = VideoPlayerController.networkUrl(url)
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Center(
            child: Column(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: () => _controller.play(),
                        icon: const Icon(Icons.play_arrow)),
                    IconButton(
                        onPressed: () {
                          _controller.seekTo(Duration.zero);
                          _controller.play();
                        },
                        icon: const Icon(Icons.replay)),
                    IconButton(
                        onPressed: () => _controller.pause(),
                        icon: const Icon(Icons.pause)),
                  ],
                )
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

