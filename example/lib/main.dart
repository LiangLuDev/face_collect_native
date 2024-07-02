import 'package:face_collect_native/face_collect_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Uint8List? faceBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Collect')),
      body: Center(
        child: Column(
          children: [
            MaterialButton(
              color: Colors.deepPurpleAccent,
              onPressed: () async {
                PermissionStatus status = await Permission.camera.request();
                if (status.isGranted) {
                  Uint8List? faceBytes = await FaceCollectScreen.show(context);
                  if (faceBytes != null) {
                    setState(() {
                      this.faceBytes = faceBytes;
                    });
                  }
                }
              },
              child: const Text(
                'Face Collect',
                style: TextStyle(color: Colors.white),
              ),
            ),
            if (faceBytes != null)
              Image.memory(faceBytes!, width: 300, fit: BoxFit.cover),
          ],
        ),
      ),
    );
  }
}
