import 'dart:io';
import 'dart:convert';


import 'package:camera/camera.dart';
import 'package:faceauth/server_url.dart';
import 'package:faceauth/util.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

import 'authentication.dart'; // Needed for using basename with the file path

class Registration extends StatefulWidget {


  const Registration({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<Registration> {
  final picker = ImagePicker();
  String _responseMessage = "";
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  late final firstCamera;

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
    // Create a MultipartRequest
    var request = MultipartRequest('POST', Uri.parse(ServerUrl.baseUrl + ServerUrl.register)  );
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

  Future<void> _authenticateFace(BuildContext context ) async {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>   const Authentication(

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
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'User Id'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'User Name'),
                ),
                const SizedBox(height: 40),
                _imageFile == null
                    ? Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: const BorderRadius.all(Radius.circular(10))
                  ),
                  child: SizedBox(
                      height: 280,
                      width: 230,
                      child: Center(child: Text('User Image'))),
                )
                    : Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: const BorderRadius.all(Radius.circular(10))
                  ),
                  child: SizedBox(
                      height: 280,
                      width: 230,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_imageFile!,fit: BoxFit.fill,))),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Capture Image'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        _uploadImageToServer();
                      },
                      child: const Text('Registration'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _authenticateFace(context);
                      },
                      child: const Text('Authenticate'),
                    ),
                  ],
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