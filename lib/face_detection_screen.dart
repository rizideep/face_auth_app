import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:faceauth/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart';
import 'package:lottie/lottie.dart';
import 'package:path/path.dart';

class FaceDetectionScreen extends StatefulWidget {
  final String url;

  const FaceDetectionScreen(this.url, {super.key});

  @override
  FaceDetectionScreenState createState() => FaceDetectionScreenState();
}

class FaceDetectionScreenState extends State<FaceDetectionScreen> {
  CameraController? _controller;

  bool isProcessing = false;
  int blinkCount = 0; // To count the blinks

  late List<CameraDescription> cameras;

  bool isFrontCamera = true; // Track the camera type (front or back)
  late FaceDetector _faceDetector;

  var _responseMessage;

  int openToCloseFrames = 0; // Frames between eye opening and closing
  int closeToOpenFrames = 0; // Frames between eye closing and opening
  bool isLeftEyeOpenInInitialFrame = false;
  bool isRightEyeOpenInInitialFrame = false;
  int maxFrameWindow = 5; // Max number of frames allowed for a blink transition

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  Future<void> _initializeCamera([CameraDescription? cameraDescription]) async {
    blinkCount = 0;
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: true,
          enableLandmarks: true,
          enableClassification: true,
        ),
      );

      cameras = await availableCameras();

      CameraDescription selectedCamera = cameraDescription ??
          cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front,);

      _controller = CameraController(selectedCamera, ResolutionPreset.high);
      await _controller?.initialize();

        _controller?.startImageStream((CameraImage image) async {
          if (!isProcessing) {
            await detectFaces(image);
          }
        });

    } catch (e) {
      MyUtil.showToast("Error initializing camera: $e");
      if (kDebugMode) {
        print("Camera initialization error: $e");
      }
    }
  }

  Future<void> detectFaces(CameraImage image) async {
    if (!isProcessing) {
      setState(() {
        isProcessing = true;
      });

      try {
        final InputImage inputImage = _convertCameraImageToInputImage(image);
        List<Face> faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          for (Face face in faces) {
            _detectBlinks(face);

            if (blinkCount >= 3) {
              if (_controller?.value.isStreamingImages == true) {
                MyUtil.showToast("face detected");
                await _controller?.stopImageStream();
                await _faceDetector.close();
                File authenticationFile = File(inputImage.filePath!);
                _authentications(authenticationFile);
              }
            }
          }
        }
      } catch (error) {
        if (mounted) {
          MyUtil.showToast("Error in face detection: $error");
        }
        print("Face detection error: $error");
      } finally {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  InputImage _convertCameraImageToInputImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation imageRotation =
        _rotationIntToImageRotation(_controller!.description.sensorOrientation);

    final inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      bytesPerRow: image.planes[0].bytesPerRow,
      format: InputImageFormat.nv21,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  InputImageRotation _rotationIntToImageRotation(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Future<void> _authentications(File imageFile) async {
    var request = MultipartRequest(
        'POST', Uri.parse('http://192.168.1.9:8000/authenticate/'));
    var stream = ByteStream(imageFile.openRead());
    var length = await imageFile.length();
    var multipartFile = MultipartFile('image', stream, length,
        filename: basename(imageFile.path));
    request.files.add(multipartFile);

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        var responseDataa = await Response.fromStream(response);
        setState(() {
          _responseMessage = responseDataa.body;
        });
        if (kDebugMode) {
          print('Success: ${jsonResponse['message']}');
        }
      } else {
        if (kDebugMode) {
          print('Failed with status code: ${response.statusCode}');
        }
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        if (kDebugMode) {
          print('Error: ${jsonResponse['error']}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller?.stopImageStream();
    }
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Lottie Animation Overlay
                Positioned.fill(
                  child: Lottie.asset(
                    'assets/lottie_file/face_animation.json',
                    fit: BoxFit.contain,
                    repeat: true, // Ensure the animation keeps repeating
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 120.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ElevatedButton(
                      onPressed: _resetDetection,
                      child: const Text('Reset'),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ElevatedButton(
                      onPressed: _toggleCamera,
                      child: const Text('Toggle'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Method to toggle between front and back cameras
  Future<void> _toggleCamera() async {
    setState(() {
      isFrontCamera = !isFrontCamera;
    });

    // Select the opposite camera (front or back)
    CameraDescription newCamera = cameras.firstWhere(
      (camera) =>
          camera.lensDirection ==
          (isFrontCamera
              ? CameraLensDirection.front
              : CameraLensDirection.back),
    );

    if (_controller?.value.isStreamingImages == true) {
      MyUtil.showToast("face detected");
      await _controller?.stopImageStream();
      await _faceDetector.close();
    }
    await _initializeCamera(newCamera); // Initialize the new camera
  }

  void _resetDetection() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller?.stopImageStream();
    }
    await _initializeCamera();
  }

  Future<void> _detectBlinks(Face face) async {
    bool blinkDetected = false;

    // Detect left eye blink
    if (face.leftEyeOpenProbability != null) {
      double leftEyeOpenProb = face.leftEyeOpenProbability!;

      if (!isLeftEyeOpenInInitialFrame && leftEyeOpenProb > 0.5) {
        // If eye is open in the initial frame
        isLeftEyeOpenInInitialFrame = true;
        openToCloseFrames = 0; // Reset the close frame counter
      } else if (isLeftEyeOpenInInitialFrame && leftEyeOpenProb < 0.5) {
        // If the eye is open and now closed, track the frames
        openToCloseFrames++;
        if (openToCloseFrames <= maxFrameWindow) {
          blinkDetected = true;
        } else {
          openToCloseFrames = 0; // Reset after max frames exceeded
          isLeftEyeOpenInInitialFrame = false;
        }
      } else if (!isLeftEyeOpenInInitialFrame && leftEyeOpenProb < 0.5) {
        // Eye started closed, wait for it to open within the frame window
        closeToOpenFrames++;
        if (closeToOpenFrames <= maxFrameWindow) {
          blinkDetected = true;
        } else {
          closeToOpenFrames = 0; // Reset after max frames exceeded
          isLeftEyeOpenInInitialFrame = false;
        }
      }
    }

    // Detect right eye blink
    if (face.rightEyeOpenProbability != null) {
      double rightEyeOpenProb = face.rightEyeOpenProbability!;

      if (!isRightEyeOpenInInitialFrame && rightEyeOpenProb > 0.5) {
        // If eye is open in the initial frame
        isRightEyeOpenInInitialFrame = true;
        openToCloseFrames = 0; // Reset the close frame counter
      } else if (isRightEyeOpenInInitialFrame && rightEyeOpenProb < 0.5) {
        // If the eye is open and now closed, track the frames
        openToCloseFrames++;
        if (openToCloseFrames <= maxFrameWindow) {
          blinkDetected = true;
        } else {
          openToCloseFrames = 0; // Reset after max frames exceeded
          isRightEyeOpenInInitialFrame = false;
        }
      } else if (!isRightEyeOpenInInitialFrame && rightEyeOpenProb < 0.5) {
        // Eye started closed, wait for it to open within the frame window
        closeToOpenFrames++;
        if (closeToOpenFrames <= maxFrameWindow) {
          blinkDetected = true;
        } else {
          closeToOpenFrames = 0; // Reset after max frames exceeded
          isRightEyeOpenInInitialFrame = false;
        }
      }
    }

    if (blinkDetected) {
      blinkCount++;
      if (kDebugMode) {
        print("Blink detected! Total blinks: $blinkCount");
      }
    } else {
      if (kDebugMode) {
        print("No blink detected.");
      }
    }
  }
}
