# Liveness face collect native
A plugin for liveness face recognition and capture. support Android and iOS

### Features
- To recognize a face, keep still within the face recognition frame to ensure clarity and accuracy.
- Determine if you are a real person through blinking and smiling.
- Animation during facial scanning.
- Return a clear and accurate image of the face.

### Screenshot
<table>
  <tr>
    <td><img src="https://github.com/LiangLuDev/face_collect_native/raw/main/screenshot/init_screenshot.png" width="250px"/></td>
    <td><img src="https://github.com/LiangLuDev/face_collect_native/raw/main/screenshot/smile_screenshot.png" width="250px"/></td>
    <td><img src="https://github.com/LiangLuDev/face_collect_native/raw/main/screenshot/blink_screenshot.png" width="250px"/></td>
  </tr>
</table>

### How to use

```dart
PermissionStatus status = await Permission.camera.request();
  if (status.isGranted) {
    Uint8List? faceBytes = await FaceCollectScreen.show(context);
    if (faceBytes != null) {
      setState(() {
        this.faceBytes = faceBytes;
      });
    }
  }
  
/// show face image
Image.memory(faceBytes!, width: 300, fit: BoxFit.cover),

```
