import 'dart:math';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceStatus {
  unknown,
  outside, // Face detected, but not in the frame
  smile, // Face detected &  in the frame & smile
  blink, // Face detected &  in the frame & blink
  finish, //  Face collected
}

enum BlinkState {
  none, // initial state
  eyesOpen, // open eyes
  eyesClosed, // close eyes
}

class FaceMLHelper {
  FaceMLHelper._privateConstructor();

  static final FaceMLHelper instance = FaceMLHelper._privateConstructor();

  /// Keep still and steady for multiple continuous shots for successful collect.
  final List<Face> _tempFaces = [];

  BlinkState _currentBlinkState = BlinkState.none;
  DateTime? _blinkStartTime;

  bool _isSmilePassed = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
        enableContours: true,
        enableClassification: true,
        enableLandmarks: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.85),
  );

  /// [stabilityCount] Number of continuous steady shots required.
  /// [eyeOpenProbability] Probability of eyes being open.
  Future<Face?> processCameraImage(
    InputImage inputImage, {
    required Size screenSize,
    required Size regionSize,
    int stabilityCount = 10,
    double eyeOpenProbability = 0.75,
    Function(FaceStatus)? onFaceLiveStatusChange,
  }) async {
    final List<Face> faces = await _faceDetector.processImage(inputImage);

    if (faces.isNotEmpty && faces.length == 1) {
      Face face = faces.first;

      /// Complete organ and part check.
      bool isLandmarks = _checkLandmarks(face);
      var isFaceRegionInside = _isFaceRegionInside(
          boundingBox: face.boundingBox,
          screenSize: screenSize,
          cameraSize: inputImage.metadata!.size,
          regionSize: regionSize);

      if (isLandmarks && isFaceRegionInside) {
        _tempFaces.add(face);
        if (_tempFaces.length > stabilityCount) {
          // Detect Smile
          if (!_isSmilePassed) {
            onFaceLiveStatusChange?.call(FaceStatus.smile);
            bool isSmiling = (face.smilingProbability ?? 0.0) > 0.8;

            if (isSmiling) {
              _isSmilePassed = true;
            } else {
              return null;
            }
          }

          // A blink is defined as closing and reopening the eyes within 2 seconds.
          bool eyesOpen = (face.leftEyeOpenProbability ?? 0.0) > 0.75 &&
              (face.rightEyeOpenProbability ?? 0.0) > 0.75;
          bool eyesClosed = (face.leftEyeOpenProbability ?? 1.0) < 0.25 &&
              (face.rightEyeOpenProbability ?? 1.0) < 0.25;

          onFaceLiveStatusChange?.call(FaceStatus.blink);

          if (_handleBlinkState(eyesOpen, eyesClosed)) {
            _faceDetector.close();
            _tempFaces.clear();
            onFaceLiveStatusChange?.call(FaceStatus.finish);
            return face;
          }
        }
      } else {
        /// Not in the frame, need restart the process
        _resetAllStates();
        onFaceLiveStatusChange?.call(FaceStatus.outside);
      }
    } else {
      _tempFaces.clear();
      onFaceLiveStatusChange?.call(FaceStatus.outside);
    }
    return null;
  }

  /// Check if the face is within the specified area.
  /// [boundingBox] Detected region of the face
  /// [screenSize] Screen size
  /// [cameraSize] Coordinates of the camera area
  /// [regionSize] Face frame area
  /// [minimumCoverage] Face-to-frame overlap ratio, from 0 to 1
  bool _isFaceRegionInside(
      {required Rect boundingBox,
      required Size screenSize,
      required Size cameraSize,
      required Size regionSize,
      double minimumCoverage = 0.7}) {
    if (cameraSize.width > cameraSize.height) {
      cameraSize = Size(cameraSize.height, cameraSize.width);
    }

    final double scaleX = screenSize.width / cameraSize.width;
    final double scaleY = screenSize.height / cameraSize.height;

    final double centerX = boundingBox.left + boundingBox.width / 2;
    final double centerY = boundingBox.top + boundingBox.height / 2;
    final double normalizedCenterX =
        (centerX * scaleX - screenSize.width / 2) / (regionSize.width / 2);
    final double normalizedCenterY =
        (centerY * scaleY - screenSize.height / 2) / (regionSize.height / 2);
    final double distanceSquared = normalizedCenterX * normalizedCenterX +
        normalizedCenterY * normalizedCenterY;

    if (distanceSquared <= 1) {
      double overlapArea = _calculateEllipseRectangleOverlap(
          boundingBox: boundingBox,
          scaleX: scaleX,
          scaleY: scaleY,
          regionSize: regionSize,
          screenSize: screenSize);

      double boxArea = boundingBox.width * boundingBox.height * scaleX * scaleY;
      double coverage = overlapArea / boxArea;

      return coverage >= minimumCoverage;
    }
    return false;
  }

  /// Area of overlap between the face and the bounding box.
  double _calculateEllipseRectangleOverlap(
      {required Rect boundingBox,
      required double scaleX,
      required double scaleY,
      required Size regionSize,
      required Size screenSize}) {
    double a = regionSize.width / 2;
    double b = regionSize.height / 2;

    double rectLeft = boundingBox.left * scaleX;
    double rectRight = boundingBox.right * scaleX;
    double rectTop = boundingBox.top * scaleY;
    double rectBottom = boundingBox.bottom * scaleY;

    double overlapWidth = max(
        0,
        min(screenSize.width / 2 + a, rectRight) -
            max(screenSize.width / 2 - a, rectLeft));
    double overlapHeight = max(
        0,
        min(screenSize.height / 2 + b, rectBottom) -
            max(screenSize.height / 2 - b, rectTop));

    return overlapWidth * overlapHeight;
  }

  bool _checkLandmarks(Face face) {
    if (face.landmarks[FaceLandmarkType.bottomMouth] == null ||
        face.landmarks[FaceLandmarkType.rightMouth] == null ||
        face.landmarks[FaceLandmarkType.leftMouth] == null ||
        face.landmarks[FaceLandmarkType.rightEye] == null ||
        face.landmarks[FaceLandmarkType.leftEye] == null ||
        face.landmarks[FaceLandmarkType.rightEar] == null ||
        face.landmarks[FaceLandmarkType.leftEar] == null ||
        face.landmarks[FaceLandmarkType.rightCheek] == null ||
        face.landmarks[FaceLandmarkType.leftCheek] == null ||
        face.landmarks[FaceLandmarkType.noseBase] == null) {
      return false;
    }
    return true;
  }

  bool _handleBlinkState(bool eyesOpen, bool eyesClosed) {
    switch (_currentBlinkState) {
      case BlinkState.none:
        if (eyesOpen) {
          _currentBlinkState = BlinkState.eyesOpen;
          _blinkStartTime = DateTime.now();
        }
        return false;

      case BlinkState.eyesOpen:
        if (eyesClosed) {
          _currentBlinkState = BlinkState.eyesClosed;
        } else if (_isBlinkTimeout()) {
          _resetBlinkState();
        }
        return false;

      case BlinkState.eyesClosed:
        if (eyesOpen) {
          if (!_isBlinkTimeout()) {
            return true;
          }
        }
        if (_isBlinkTimeout()) {
          _resetBlinkState();
        }
        return false;
    }
  }

  bool _isBlinkTimeout() {
    if (_blinkStartTime == null) return true;
    return DateTime.now().difference(_blinkStartTime!) >
        const Duration(seconds: 2);
  }

  void _resetBlinkState() {
    _currentBlinkState = BlinkState.none;
    _blinkStartTime = null;
  }

  void _resetAllStates() {
    _tempFaces.clear();
    _isSmilePassed = false;
    _resetBlinkState();
  }

  dispose() {
    _faceDetector.close();
  }
}
