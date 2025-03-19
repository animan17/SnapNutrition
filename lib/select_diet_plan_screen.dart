import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_data.dart';
import 'common_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';

class SelectDietPlanScreen extends StatefulWidget {
  const SelectDietPlanScreen({super.key});

  @override
  State<SelectDietPlanScreen> createState() => _SelectDietPlanScreenState();
}

class _SelectDietPlanScreenState extends State<SelectDietPlanScreen> {
  final AppData appData = AppData();
  bool _isLoading = false;
  AINutritionResponse? _aiResponse;
  bool _showAdditionalQuestions = false;

  // Form controllers
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _goalController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedActivityLevel = 'Moderate';
  
  // Additional info that AI might request
  final Map<String, String> _additionalInfo = {};

  final String geminiApiKey = 'AIzaSyDyvE8u8BDGS0EBtL_mD9hucKblndBlJHc';
  final String geminiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // Add nutrient colors to match plots
  static final nutrientColors = {
    'Protein': Colors.green,
    'Carbohydrates': Colors.orange,
    'Fat': Colors.blue,
  };

  Future<void> _generateDietPlan() async {
    setState(() {
      _isLoading = true;
      _aiResponse = null;
    });

    try {
      final prompt = '''
You are a professional nutritionist. Based on the following information, provide a brief one-paragraph recommendation and daily macronutrient targets.

User Details:
- Weight: ${_weightController.text} kg
- Height: ${_heightController.text} cm
- Age: ${_ageController.text} years
- Gender: $_selectedGender
- Activity Level: $_selectedActivityLevel
- Fitness Goal: ${_goalController.text}
${_additionalInfo.isEmpty ? '' : '\nAdditional Information:'}
${_additionalInfo.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

IMPORTANT: Respond ONLY with a JSON object in exactly this format, with no additional text before or after:
{
  "needMoreInfo": false,
  "additionalQuestions": [],
  "recommendations": {
    "Protein": 0,
    "Carbohydrates": 0,
    "Fat": 0
  },
  "explanation": "One brief paragraph summarizing the recommendations.",
  "confidence": 0.0
}
''';

      print("[DEBUG] Sending prompt to Gemini API:");
      print(prompt);

      
      final String endpointWithKey = '$geminiEndpoint?key=$geminiApiKey';
      final response = await http.post(
        Uri.parse(endpointWithKey),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 1,
            'topP': 1,
          },
        }),
      );

      print("[DEBUG] Gemini API raw response:");
      print(response.body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final aiText = jsonResponse['candidates'][0]['content']['parts'][0]['text'];
        
        print("[DEBUG] Extracted AI text:");
        print(aiText);
        
        try {
          // Try to parse the response directly first
          final recommendations = AINutritionResponse.fromJson(jsonDecode(aiText));
          setState(() {
            _aiResponse = recommendations;
            _showAdditionalQuestions = recommendations.needMoreInfo;
            
            if (!recommendations.needMoreInfo) {
              appData.updateDailyTargets(recommendations.recommendations);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Diet Plan applied!')),
              );
            }
          });
        } catch (e) {
          // If direct parsing fails, try cleaning the response
          print("[DEBUG] Direct parsing failed, attempting to clean response");
          final cleanText = aiText
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim()
            .replaceAll(RegExp(r'[\r\n\t]'), '')  // Remove newlines and tabs
            .replaceAll(RegExp(r'\s{2,}'), ' ');  // Replace multiple spaces with single space
          
          print("[DEBUG] Cleaned text:");
          print(cleanText);
          
          final recommendations = AINutritionResponse.fromJson(jsonDecode(cleanText));
          setState(() {
            _aiResponse = recommendations;
            _showAdditionalQuestions = recommendations.needMoreInfo;
            
            if (!recommendations.needMoreInfo) {
              appData.updateDailyTargets(recommendations.recommendations);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('AI Diet Plan applied!')),
              );
            }
          });
        }
      }
    } catch (e, stack) {
      print("[ERROR] Failed to generate diet plan: $e");
      print("[ERROR] Stack trace: $stack");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate diet plan. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBasicInfoCard(),
              const SizedBox(height: 16),
              _buildGoalCard(),
              if (_showAdditionalQuestions && _aiResponse != null)
                _buildAdditionalQuestionsCard(),
              if (_aiResponse != null && !_showAdditionalQuestions)
                _buildRecommendationsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basic Information', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedGender = value!),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedActivityLevel,
              decoration: const InputDecoration(
                labelText: 'Activity Level',
                border: OutlineInputBorder(),
              ),
              items: ['Sedentary', 'Light', 'Moderate', 'Active', 'Very Active']
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedActivityLevel = value!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fitness Goal', style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _goalController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Describe your fitness goal',
                hintText: 'e.g., Lose 10kg in 3 months, Build muscle mass, Maintain current weight',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateDietPlan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate AI Diet Plan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final recommendations = _aiResponse!.recommendations;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Recommendations', 
                style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // Confidence indicator
            Row(
              children: [
                Text('Confidence: ',
                    style: GoogleFonts.lato(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )),
                Expanded(
                  child: LinearProgressIndicator(
                    value: _aiResponse!.confidence,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _aiResponse!.confidence > 0.7 
                        ? Colors.green 
                        : _aiResponse!.confidence > 0.4 
                          ? Colors.orange 
                          : Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(_aiResponse!.confidence * 100).toInt()}%',
                    style: GoogleFonts.lato(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            // Simple explanation text
            Text(
              _aiResponse!.explanation,
              style: GoogleFonts.lato(
                fontSize: 16,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            // Simplified macro targets
            Center(
              child: Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _buildSimpleMacroText('Protein', recommendations['Protein']!, nutrientColors['Protein']!),
                  _buildSimpleMacroText('Carbs', recommendations['Carbohydrates']!, nutrientColors['Carbohydrates']!),
                  _buildSimpleMacroText('Fat', recommendations['Fat']!, nutrientColors['Fat']!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleMacroText(String macro, int value, Color color) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$macro: ',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          TextSpan(
            text: '$value g',
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalQuestionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Additional Information Needed',
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._aiResponse!.additionalQuestions.map<Widget>((question) {
              final controller = TextEditingController();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: question,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _additionalInfo[question] = value;
                  },
                ),
              );
            }).toList(),
            ElevatedButton(
              onPressed: _additionalInfo.length == _aiResponse!.additionalQuestions.length
                  ? _generateDietPlan
                  : null,
              child: const Text('Submit Additional Information'),
            ),
          ],
        ),
      ),
    );
  }
}

class AINutritionResponse {
  final bool needMoreInfo;
  final List<String> additionalQuestions;
  final Map<String, int> recommendations;
  final String explanation;
  final double confidence;  // Add confidence field

  AINutritionResponse({
    required this.needMoreInfo,
    required this.additionalQuestions,
    required this.recommendations,
    required this.explanation,
    required this.confidence,
  });

  factory AINutritionResponse.fromJson(Map<String, dynamic> json) {
    return AINutritionResponse(
      needMoreInfo: json['needMoreInfo'] as bool,
      additionalQuestions: List<String>.from(json['additionalQuestions'] ?? []),
      recommendations: Map<String, int>.from(json['recommendations']?.map(
            (key, value) => MapEntry(key, (value as num).toInt()),
          ) ??
          {}),
      explanation: json['explanation'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
