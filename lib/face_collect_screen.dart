import 'package:camera/camera.dart';
import 'package:face_collect_native/face_image_util.dart';
import 'package:face_collect_native/face_ml_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:lottie/lottie.dart';

export "package:face_collect_native/face_collect_screen.dart";

class FaceCollectScreen extends StatefulWidget {
  /// Face recognition frame width and height
  /// (adjusting the frame position is not supported, it can only be centered)
  Size? ovalSize;

  /// Face recognition prompt text
  String? initHint;

  /// Face recognition prompt text style
  TextStyle? promptStyle;

  String? smileHint;

  String? blinkHint;

  static Future show(BuildContext context,
      {Size? ovalSize,
      String? initHint,
      String? smileHint,
      String? blinkHint,
      TextStyle? promptStyle}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => FaceCollectScreen(
                initHint: initHint,
                smileHint: smileHint,
                blinkHint: blinkHint,
                promptStyle: promptStyle,
                ovalSize: ovalSize,
              )),
    );
  }

  FaceCollectScreen(
      {super.key,
      this.initHint,
      this.smileHint,
      this.blinkHint,
      this.promptStyle,
      this.ovalSize});

  @override
  State<FaceCollectScreen> createState() => _FaceCollectScreenState();
}

class _FaceCollectScreenState extends State<FaceCollectScreen> {
  CameraController? _cameraController;

  int? _cameraSensorOrientation;

  bool _isProcessing = false;

  Widget? _cameraView;

  late Size _ovalSize;

  final String _lottiePath = 'packages/face_collect_native/assets/scan.json';

  FaceStatus _faceStatus = FaceStatus.unknown;

  @override
  void initState() {
    super.initState();
    _ovalSize = widget.ovalSize ?? const Size(250, 360);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _initCamera(),
    );
  }

  Future<void> _initCamera() async {
    List<CameraDescription> availableCams = await availableCameras();
    int cameraIndex = -1;
    if (availableCams.any(
      (element) =>
          element.lensDirection == CameraLensDirection.front &&
          element.sensorOrientation == 90,
    )) {
      cameraIndex = availableCams.indexOf(
        availableCams.firstWhere((element) =>
            element.lensDirection == CameraLensDirection.front &&
            element.sensorOrientation == 90),
      );
    } else {
      cameraIndex = availableCams.indexOf(
        availableCams.firstWhere(
          (element) => element.lensDirection == CameraLensDirection.front,
        ),
      );
    }
    if (cameraIndex > -1) {
      var camera = availableCams[cameraIndex];
      _cameraSensorOrientation = camera.sensorOrientation;
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraController!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        _cameraView = CameraPreview(_cameraController!);
        _cameraController?.startImageStream(_processCameraImage);
        setState(() {});
      });
    } else {
      debugPrint('Camera not found');
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (!mounted) return;
    if (_cameraSensorOrientation == null) return;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      cameraImage.width.toDouble(),
      cameraImage.height.toDouble(),
    );

    final imageRotation =
        InputImageRotationValue.fromRawValue(_cameraSensorOrientation!);
    if (imageRotation == null) return;

    final inputImageFormat = InputImageFormatValue.fromRawValue(
      cameraImage.format.raw,
    );
    if (inputImageFormat == null) return;

    int? bytesPerRow;
    if (cameraImage.planes.isNotEmpty) {
      bytesPerRow = cameraImage.planes.first.bytesPerRow;
    }

    if (bytesPerRow == null) return;

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: bytesPerRow),
    );

    if (_isProcessing) return;
    _isProcessing = true;

    var face = await FaceMLHelper.instance.processCameraImage(
      inputImage,
      screenSize: context.size!,
      regionSize: _ovalSize,
      onFaceLiveStatusChange: (status) {
        if (!mounted) return;
        _faceStatus = status;
        setState(() {});
      },
    );

    if (face != null) {
      await _cameraController?.stopImageStream();
      HapticFeedback.lightImpact();
      Uint8List? faceImage = FaceImageUtils.convertCameraImage(cameraImage);
      if (mounted) {
        Navigator.of(context).pop(faceImage);
      }
    } else {
      debugPrint('Face Image Process Fail');
    }
    _isProcessing = false;
  }

  @override
  void dispose() {
    FaceMLHelper.instance.dispose();
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildCameraWidget();
  }

  Widget _buildCameraWidget() {
    if (_cameraController == null ||
        _cameraController?.value.isInitialized == false ||
        _cameraView == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return SafeArea(
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            if (_cameraView != null) Container(child: _cameraView),
            Center(
              child: Lottie.asset(
                _lottiePath,
                repeat: true,
                width: _ovalSize.width,
                height: _ovalSize.height,
                fit: BoxFit.fill,
              ),
            ),
            PositionedDirectional(
                top: 42,
                start: 32,
                end: 32,
                child: Text(
                  _buildHintStr(),
                  textAlign: TextAlign.center,
                  style: widget.promptStyle ??
                      TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                            offset: const Offset(0.0, 2.0),
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4.0,
                          )
                        ],
                      ),
                )),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 10,
                  top: 30,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildHintStr() {
    switch (_faceStatus) {
      case FaceStatus.blink:
        return widget.blinkHint ?? 'Blink';
      case FaceStatus.smile:
        return widget.smileHint ?? 'Smile';
      case FaceStatus.finish:
        return 'Successfully';
      default:
        return widget.initHint ?? 'Blink';
    }
  }
}
