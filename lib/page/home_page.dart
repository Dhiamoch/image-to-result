import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ImageSourceOption { camera, gallery }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? _imageFile;
  bool _isProcessing = false;
  ImageSourceOption? _selectedSource;
  List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _results = prefs.getStringList('results') ?? [];
    });
  }

  Future<void> _saveResult(String result) async {
    final prefs = await SharedPreferences.getInstance();
    _results.add(result);
    await prefs.setStringList('results', _results);
  }

  Future<void> _pickImage() async {
    if (_selectedSource == null) return;

    final source = _selectedSource == ImageSourceOption.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final pickFile = await ImagePicker().pickImage(source: source);
    if (pickFile != null) {
      setState(() {
        _imageFile = File(pickFile.path);
        _isProcessing = true;
      });
      await _processImage();
    }
  }

  Future<void> _processImage() async {
    if (_imageFile == null) return;

    final inputImage = InputImage.fromFilePath(_imageFile!.path);
    final textRecognizer = TextRecognizer();
    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);
      String text = recognizedText.text;

      final result = _calculateExpression(text);
      if (result != null) {
        await _saveResult(result);
      }
    } finally {
      textRecognizer.close();
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String? _calculateExpression(String text) {
    try {
      Parser parser = Parser();
      Expression exp = parser.parse(text.replaceAll(' ', ''));
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      return 'input : $text\nresult: ${eval.toInt()}';
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_results[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                ListTile(
                  title: const Text('Camera'),
                  leading: Radio<ImageSourceOption>(
                    value: ImageSourceOption.camera,
                    groupValue: _selectedSource,
                    onChanged: (ImageSourceOption? value) {
                      setState(() {
                        _selectedSource = value;
                      });
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Gallery'),
                  leading: Radio<ImageSourceOption>(
                    value: ImageSourceOption.gallery,
                    groupValue: _selectedSource,
                    onChanged: (ImageSourceOption? value) {
                      setState(() {
                        _selectedSource = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _selectedSource == null || _isProcessing ? null : _pickImage,
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Pick Image'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
