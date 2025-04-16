import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:barcode_scan2/barcode_scan2.dart';
import 'app_data.dart'; // Import our global data
import 'common_app_bar.dart';
import 'main.dart';  // Add this import at the top  
import 'test_date_dialog.dart';  // Add this import

class SnapPhotoScreen extends StatefulWidget {
  const SnapPhotoScreen({Key? key}) : super(key: key);

  @override
  State<SnapPhotoScreen> createState() => _SnapPhotoScreenState();
}

class _SnapPhotoScreenState extends State<SnapPhotoScreen> {
  File? _image;
  String _result = '';
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _parsedData;
  Meal? _currentMeal;

  Map<String, dynamic>? barcodeMacros;
  String? barcodeValue;
  bool isBarcodeLoading = false;
  bool barcodeAdded = false;

  // Replace with your actual Gemini API key and endpoint.
  final String geminiApiKey = 'AIzaSyDyvE8u8BDGS0EBtL_mD9hucKblndBlJHc';
  final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  @override
  void initState() {
    super.initState();
    // Show date picker dialog when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDateDialog();
    });
  }

  Future<void> _showDateDialog() async {
    final String? testDate = await showDialog<String>(
      context: context,
      barrierDismissible: false, // User must pick an option
      builder: (BuildContext context) => const TestDateDialog(),
    );
    
    if (testDate != null) {
      AppData.setDebugDate(testDate);
      print('[DEBUG] Using test date: $testDate');
    }
  }

  /// Capture an image using the device camera.
  Future<void> _captureImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 600,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = ''; // Clear previous results.
      });
      await _analyzeImage(_image!);
    }
  }

  Future<void> _analyzeImage(File imageFile) async {
    setState(() {
      _isLoading = true;
      _result = 'Analyzing image...';
      _parsedData = null; // Clear previous data
      _currentMeal = null;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final Map<String, dynamic> payload = {
        "contents": [
          {
            "parts": [
              {
                "text": """Analyze this food image. Return a JSON object with an 'items' array where each item has 'name', 'quantity' (in grams), and 'macronutrientsPer100g' (with 'Carbohydrates', 'Fat', 'Protein' in grams). Example format:
                {
                  "items": [
                    {
                      "name": "Rice",
                      "quantity": 150,
                      "macronutrientsPer100g": {
                        "Carbohydrates": 28,
                        "Fat": 0.3,
                        "Protein": 2.7
                      }
                    }
                  ]
                }"""
              },
              {
                "inlineData": {"mimeType": "image/jpeg", "data": base64Image}
              }
            ]
          }
        ]
      };

      final String endpointWithKey = '$geminiEndpoint?key=$geminiApiKey';
      final response = await http.post(
        Uri.parse(endpointWithKey),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      // Inside _analyzeImage method, replace the JSON parsing section:
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print("[DEBUG] Raw API response: $jsonData");

        try {
          // Extract text from Gemini response
          String? extractedText;
          if (jsonData['candidates']?[0]?['content']?['parts']?[0]?['text'] != null) {
            extractedText = jsonData['candidates'][0]['content']['parts'][0]['text'];
            print("[DEBUG] Raw extracted text: $extractedText");
          } else {
            throw Exception('Invalid API response structure');
          }

          // Clean and parse the JSON
          final cleanResult = _cleanJsonString(extractedText!);
          print("[DEBUG] Cleaned JSON string: $cleanResult");
          
          _parsedData = json.decode(cleanResult);
          if (!_parsedData!.containsKey('items')) {
            throw Exception('Response missing items array');
          }

          setState(() {
            _result = cleanResult;
          });

          // Create and add meal immediately
          final items = _parsedData!['items'] as List;
          final List<FoodItem> foodItems = items.map((item) {
            return FoodItem(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: item['name'] as String,
              quantity: (item['quantity'] as num).toDouble(),
              macrosPer100g: {
                'Carbohydrates': (item['macronutrientsPer100g']['Carbohydrates'] as num).toDouble(),
                'Fat': (item['macronutrientsPer100g']['Fat'] as num).toDouble(),
                'Protein': (item['macronutrientsPer100g']['Protein'] as num).toDouble(),
              },
            );
          }).toList();

          final timestamp = DateTime.now();
          _currentMeal = Meal(
            id: timestamp.millisecondsSinceEpoch.toString(),
            name: foodItems.map((i) => i.name).join(", "),
            imageFilePath: _image!.path,
            timestamp: timestamp,
            items: foodItems,
          );

          final appData = AppData();
          final date = timestamp.toString().split(" ")[0];
          appData.addMeal(meal: _currentMeal);
          print("[DEBUG] Added meal with ${foodItems.length} items");

        } catch (e) {
          print("[ERROR] JSON parsing failed: $e");
          throw Exception('Failed to parse food data: $e');
        }
      }
    } catch (e) {
      print("[ERROR] Analysis failed: $e");
      setState(() {
        _result = 'Analysis error: $e';
        _parsedData = null;
        _currentMeal = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _cleanJsonString(String input) {
    var result = input.trim();
    
    // Remove markdown code blocks
    if (result.startsWith('```')) {
      result = result.replaceAll('```json', '')
                    .replaceAll('```', '')
                    .trim();
    }
    
    // Extract JSON object using regex
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(result);
    if (jsonMatch == null) {
      throw FormatException('No valid JSON object found in response');
    }
    
    return jsonMatch.group(0)!;
  }

  Map<String, double> _calculateTotalMacros(List<dynamic> items) {
    double totalCarbs = 0;
    double totalFat = 0;
    double totalProtein = 0;

    for (var item in items) {
      final quantity = (item['quantity'] as num).toDouble();
      final macros = item['macronutrientsPer100g'];
      
      totalCarbs += (macros['Carbohydrates'] as num).toDouble() * quantity / 100;
      totalFat += (macros['Fat'] as num).toDouble() * quantity / 100;
      totalProtein += (macros['Protein'] as num).toDouble() * quantity / 100;
    }

    return {
      'Carbohydrates': totalCarbs,
      'Fat': totalFat,
      'Protein': totalProtein,
    };
  }

  /// Parse the structured JSON output and update AppData with total macronutrients.
  void _updateNutrientsFromResult(String resultText, {bool isInitial = false}) async {
    if (!isInitial || _parsedData == null || !_parsedData!.containsKey('items')) {
      print("[DEBUG] Skipping nutrition update - invalid data");
      return;
    }

    try {
      final items = _parsedData!['items'] as List;
      final List<FoodItem> foodItems = items.map((item) {
        return FoodItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: item['name'] as String,
          quantity: (item['quantity'] as num).toDouble(),
          macrosPer100g: {
            'Carbohydrates': (item['macronutrientsPer100g']['Carbohydrates'] as num).toDouble(),
            'Fat': (item['macronutrientsPer100g']['Fat'] as num).toDouble(),
            'Protein': (item['macronutrientsPer100g']['Protein'] as num).toDouble(),
          },
        );
      }).toList();

      final timestamp = DateTime.now();
      _currentMeal = Meal(
        id: timestamp.millisecondsSinceEpoch.toString(),
        name: foodItems.map((i) => i.name).join(", "),
        imageFilePath: _image!.path,
        timestamp: timestamp,
        items: foodItems,
      );

      final appData = AppData();
      appData.addMeal(meal: _currentMeal);  // Updated this line
      
      print("[DEBUG] Added meal with ${foodItems.length} items");
      setState(() {}); // Trigger UI update
    } catch (e, stack) {
      print("[ERROR] Failed to update nutrients: $e");
      print("[DEBUG] Stack trace: $stack");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating nutrients: $e')),
      );
    }
  }

  void _updateItemQuantity(Map<String, dynamic> item, String newValue) {
    if (_currentMeal == null) return;

    final quantity = double.tryParse(newValue);
    if (quantity == null || quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    setState(() {
      // Update parsed data
      item['quantity'] = quantity;
      
      // Ensure item has an ID
      if (!item.containsKey('id')) {
        item['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }

      // Find and update the corresponding FoodItem
      final foodItemIndex = _currentMeal!.items.indexWhere((f) => f.id == item['id']);
      if (foodItemIndex != -1) {
        _currentMeal!.items[foodItemIndex].quantity = quantity;
        
        // Update meal in AppData
        final appData = AppData();
        appData.addMeal(meal: _currentMeal);
        
        print("[DEBUG] Updated quantity for ${item['name']}: $quantity g");
      }
    });
  }

  Future<void> scanBarcode() async {
    setState(() {
      isBarcodeLoading = true;
      barcodeMacros = null;
      barcodeValue = null;
      barcodeAdded = false;
    });

    // Only use the barcode scanner, do not prompt for a separate camera image
    var result = await BarcodeScanner.scan();
    if (result.type == ResultType.Barcode && result.rawContent.isNotEmpty) {
      barcodeValue = result.rawContent;
      await fetchMacrosFromBarcode(barcodeValue!);

      // Use the provided barcode.webp asset as the placeholder image
      setState(() {
        _image = null; // Clear _image so Image.file is not used
      });
    }
    setState(() {
      isBarcodeLoading = false;
    });
  }

  Future<void> fetchMacrosFromBarcode(String barcode) async {
    final url = 'https://world.openfoodfacts.org/api/v0/product/$barcode.json';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final nutriments = data['product']?['nutriments'];
      final productName = data['product']?['product_name'] ?? 'Barcode Food';
      setState(() {
        barcodeMacros = {
          'name': productName,
          'Protein': nutriments != null && nutriments['proteins_100g'] != null
              ? double.tryParse(nutriments['proteins_100g'].toString())?.toStringAsFixed(1) ?? '0.0'
              : '0.0',
          'Carbohydrates': nutriments != null && nutriments['carbohydrates_100g'] != null
              ? double.tryParse(nutriments['carbohydrates_100g'].toString())?.toStringAsFixed(1) ?? '0.0'
              : '0.0',
          'Fat': nutriments != null && nutriments['fat_100g'] != null
              ? double.tryParse(nutriments['fat_100g'].toString())?.toStringAsFixed(1) ?? '0.0'
              : '0.0',
        };
        // Convert back to double for calculation, except for name
        barcodeMacros = {
          'name': barcodeMacros!['name'],
          'Protein': double.tryParse(barcodeMacros!['Protein'].toString()) ?? 0.0,
          'Carbohydrates': double.tryParse(barcodeMacros!['Carbohydrates'].toString()) ?? 0.0,
          'Fat': double.tryParse(barcodeMacros!['Fat'].toString()) ?? 0.0,
        };
      });
    }
  }

  Future<void> addBarcodeMacrosToDay() async {
    if (barcodeMacros == null) return;
    final barcodeImage = _image ?? File('');
    final foodName = barcodeMacros!['name'] ?? 'Barcode Food';
    final fakeResult = json.encode({
      "items": [
        {
          "name": foodName,
          "quantity": 100,
          "macronutrientsPer100g": {
            "Carbohydrates": barcodeMacros!['Carbohydrates'] ?? 0,
            "Fat": barcodeMacros!['Fat'] ?? 0,
            "Protein": barcodeMacros!['Protein'] ?? 0,
          }
        }
      ]
    });
    setState(() {
      _parsedData = json.decode(fakeResult);
      _result = fakeResult;
      _image = barcodeImage;
    });
    _updateNutrientsFromResult(fakeResult, isInitial: true);
    setState(() {
      barcodeAdded = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added barcode macronutrients to today!')),
    );
  }

  Widget _buildMacrosCard(Map<String, dynamic> macros) {
    final name = macros['name'] ?? 'Barcode Food';
    return Card(
      color: Colors.green.shade100,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name (per 100g):',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Carbohydrates: ${macros['Carbohydrates'] != null ? (macros['Carbohydrates'] as num).toStringAsFixed(1) : '-'}g',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Fat: ${macros['Fat'] != null ? (macros['Fat'] as num).toStringAsFixed(1) : '-'}g',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Protein: ${macros['Protein'] != null ? (macros['Protein'] as num).toStringAsFixed(1) : '-'}g',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_parsedData == null || _result.isEmpty) {
      return const Text('Waiting for analysis...');
    }

    try {
      final totals = _calculateTotalMacros(_parsedData!['items'] ?? []);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analysis Results:',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.green.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Nutrients:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Carbohydrates: ${totals['Carbohydrates']?.toStringAsFixed(1)}g'),
                  Text('Fat: ${totals['Fat']?.toStringAsFixed(1)}g'),
                  Text('Protein: ${totals['Protein']?.toStringAsFixed(1)}g'),
                ],
              ),
            ),
          ),
          if (_parsedData!['items'] != null)
            for (var item in _parsedData!['items'])
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['name']}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: '${item['quantity']}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity (g)',
                                border: OutlineInputBorder(),
                              ),
                              onFieldSubmitted: (value) => _updateItemQuantity(item, value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Nutrients per 100g:',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      if (item['macronutrientsPer100g'] != null) ...[
                        Text('Carbs: ${item['macronutrientsPer100g']['Carbohydrates']}g'),
                        Text('Fat: ${item['macronutrientsPer100g']['Fat']}g'),
                        Text('Protein: ${item['macronutrientsPer100g']['Protein']}g'),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      );
    } catch (e) {
      return Text('Error parsing result: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (barcodeMacros != null) {
      // Show asset image for barcode scan (make sure the asset path matches your pubspec.yaml)
      AssetImage barcode = const AssetImage('images/barcode.webp');
      imageWidget = Image(image: barcode, width: 400, height: 400);
    } else if (_image != null) {
      imageWidget = Image.file(_image!, height: 200);
    } else {
      imageWidget = const Text('No image captured yet.');
    }

    return Scaffold(
      appBar: const CommonAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              imageWidget,
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _captureImage,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Capture Food Image'),
                    ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Barcode'),
                onPressed: scanBarcode,
              ),
              if (isBarcodeLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              if (barcodeMacros != null)
                Column(
                  children: [
                    _buildMacrosCard(barcodeMacros!),
                    ElevatedButton(
                      onPressed: barcodeAdded ? null : addBarcodeMacrosToDay,
                      child: Text(barcodeAdded
                          ? 'Added!'
                          : 'Add to Today\'s Nutrition'),
                    ),
                  ],
                ),
              // Only show analysis result if not barcode scan
              if (barcodeMacros == null) _buildAnalysisResult(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _parsedData = null;
    _currentMeal = null;
    super.dispose();
  }

  Future<String?> _getTestDate() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => const TestDateDialog(),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final String? testDate = await _getTestDate();
    if (!mounted) return;
    
    if (testDate != null) {
      AppData.setDebugDate(testDate);
      print('[DEBUG] Using test date: $testDate');
    }

    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
    
    if (testDate != null) {
      AppData.setDebugDate(null);
    }
  }
}
