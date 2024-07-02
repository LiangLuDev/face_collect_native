import 'dart:math';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum FaceStatus {
  unknown,
  outside, // Face detected, but not in the frame
  inside, //  Face is already within the frame. Hold still
  finish, //  Face collected
}

class FaceMLHelper {
  FaceMLHelper._privateConstructor();

  static final FaceMLHelper instance = FaceMLHelper._privateConstructor();

  /// Keep still and steady for multiple continuous shots for successful collect.
  final List<Face> _tempFaces = [];

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
          if ((face.leftEyeOpenProbability ?? 0.0) > eyeOpenProbability &&
              (face.rightEyeOpenProbability ?? 0.0) > eyeOpenProbability) {
            _faceDetector.close();
            _tempFaces.clear();
            onFaceLiveStatusChange?.call(FaceStatus.finish);
            return face;
          }
        }
        if (_tempFaces.isNotEmpty) {
          onFaceLiveStatusChange?.call(FaceStatus.inside);
        }
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

  dispose() {
    _faceDetector.close();
  }
}
