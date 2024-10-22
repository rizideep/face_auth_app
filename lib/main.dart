import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:faceauth/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

import 'face_detection_screen.dart'; // Needed for using basename with the file path

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final picker = ImagePicker();
  String _responseMessage = "";
  String url = 'http://192.168.1.9:8000/';
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  late final firstCamera;
  final TextEditingController _urLController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  Future<void> _uploadImageToServer() async {
    if (_imageFile != null &&
        _idController.text.isNotEmpty &&
        _nameController.text.isNotEmpty) {
      await _uploadImage(_idController.text, _nameController.text, _imageFile!);
    } else {
      if (kDebugMode) {
        print('ID, Name, and Image must be provided.');
      }
    }
  }

  Future<void> _uploadImage(String id, String name, File imageFile) async {
    // Define the URL of your Flask server

    // Create a MultipartRequest
    var request = MultipartRequest('POST', Uri.parse('http://192.168.1.9:8000/register/'));
    // Add fields to the request
    request.fields['user_id'] = id;
    request.fields['name'] = name;
    // Add the image file to the request
    var stream = ByteStream(imageFile.openRead());
    var length = await imageFile.length();
    var multipartFile = MultipartFile('image', stream, length, filename: basename(imageFile.path));
    request.files.add(multipartFile);

    try {
      // Send the request and get the response
      var response = await request.send();
      MyUtil.showToast(response.statusCode.toString());
      // Check the response status
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
        MyUtil.showToast(responseDataa.body);
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

  Future<void> _authenticateFace(BuildContext context, String url) async {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>   FaceDetectionScreen(
            url
            )));
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        if (kDebugMode) {
          print('No image selected.');
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    inilizetions();
  }


  Future<void> inilizetions() async {
    final cameras = await availableCameras();
    // Get the front camera.
      firstCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Authentication App'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextField(
                  controller: _urLController,
                  decoration: const InputDecoration(labelText: 'Url'),
                  onChanged: (inputString){
                    setState(() {
                      url = inputString;
                    });
                  },
                ),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'ID'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 40),
                _imageFile == null
                    ? const Text('No image selected.')
                    : SizedBox(
                        height: 200,
                        width: 250,
                        child: Image.file(_imageFile!)),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Pick Image'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _uploadImageToServer();
                  },
                  child: const Text('Register Face'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _authenticateFace(context,url);
                  },
                  child: const Text('Authenticate Face'),
                ),
                const SizedBox(height: 20),
                Text(_responseMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
