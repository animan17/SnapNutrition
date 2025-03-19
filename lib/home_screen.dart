import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'app_data.dart';
import 'common_app_bar.dart';
import 'snap_photo_screen.dart'; // Add this import statement
import 'package:google_fonts/google_fonts.dart';



// Add this constant if you don't have a constants.dart file
final Map<String, Color> nutrientColors = {
  'Protein': Colors.green,
  'Carbohydrates': Colors.orange,
  'Fat': Colors.blue,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();  // Make this public
}

class HomeScreenState extends State<HomeScreen> {
  final AppData appData = AppData();  // Add this line
  Map<String, Map<String, int>> _nutritionData = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  void loadData() {
    _loadData();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      final appData = AppData();
      final nutritionHistory = await appData.getNutritionHistory();
      
      if (mounted) {
        setState(() {
          _nutritionData = nutritionHistory;
          _isLoading = false;
        });
      }
      print("[DEBUG] HomeScreen loaded nutrition data: $_nutritionData");
    } catch (e) {
      print("[ERROR] Failed to load nutrition data: $e");
    }
  }

  Widget _buildDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              _loadData();
            });
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_selectedDate.day} ${_getMonthAbbr(_selectedDate)}',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final tomorrow = DateTime.now().add(const Duration(days: 1));
            if (_selectedDate.isBefore(tomorrow)) {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 1));
                _loadData();
              });
            }
          },
        ),
      ],
    );
  }

  // Add this helper method
  String _getMonthAbbr(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] HomeScreen build called");
    final String dateStr = _selectedDate.toString().split(' ')[0];
    final nutrition = appData.getNutritionForDate(dateStr);
    
    // Get latest nutrition data
    Map<String, int> latestNutrition = {};
    if (_nutritionData.isNotEmpty) {
      final sortedKeys = _nutritionData.keys.toList()
        ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
      latestNutrition = _nutritionData[sortedKeys.first] ?? {};
    }
    
    print("[DEBUG] Latest nutrition totals: $latestNutrition");
    
    final meals = appData.getMealsForDate(dateStr);
    final dailyTargets = appData.dailyTargets;

    return _isLoading
      ? const Center(child: CircularProgressIndicator())
      : Scaffold(
          appBar: const CommonAppBar(),
          body: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateNavigator(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Nutrition",
                            style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sections: [
                                  if (nutrition['Protein'] != 0)
                                    PieChartSectionData(
                                      value: nutrition['Protein']!.toDouble(),
                                      title: 'P',
                                      color: nutrientColors['Protein']!,
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (nutrition['Carbohydrates'] != 0)
                                    PieChartSectionData(
                                      value: nutrition['Carbohydrates']!.toDouble(),
                                      title: 'C',
                                      color: nutrientColors['Carbohydrates']!,
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (nutrition['Fat'] != 0)
                                    PieChartSectionData(
                                      value: nutrition['Fat']!.toDouble(),
                                      title: 'F',
                                      color: nutrientColors['Fat']!,
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  if (nutrition.values.every((value) => value == 0))
                                    PieChartSectionData(
                                      value: 1,
                                      title: 'No Data',
                                      color: Colors.grey.shade300,
                                      radius: 80,
                                      titleStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                startDegreeOffset: -90,
                              ),
                              swapAnimationDuration: const Duration(milliseconds: 150),
                              swapAnimationCurve: Curves.linear,
                            ),
                          ),
                          const SizedBox(height: 32),  // Increased spacing
                          _buildProgressIndicator('Protein', nutrition['Protein'] ?? 0),
                          const SizedBox(height: 16),  // Increased spacing between bars
                          _buildProgressIndicator('Carbohydrates', nutrition['Carbohydrates'] ?? 0),
                          const SizedBox(height: 16),  // Increased spacing between bars
                          _buildProgressIndicator('Fat', nutrition['Fat'] ?? 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 24),
                  const Text(
                    "Today's Meals",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (meals.isEmpty)
                    const Center(child: Text('No meals recorded today'))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        return _buildMealCard(context, meal);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
  }

  Widget _buildMacroChart(String label, int consumed, int goal, Color color) {
    double percentage = goal > 0 ? consumed / goal : 0;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          width: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: percentage,
                      color: color,
                      radius: 50,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: 1 - percentage,
                      color: Colors.grey.shade300,
                      radius: 50,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$consumed/${goal}g',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('${(goal - consumed).clamp(0, goal)}g left'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, Meal meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SnapPhotoScreen()),
          ).then((value) {
            // If value is true (meaning data was updated) then force rebuild.
            setState(() {});
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.file(
              File(meal.imageFilePath),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNutrientBadge(
                        Icons.grain,
                        Colors.orange,
                        'Protein',
                        meal.getTotalNutrient('Protein'),
                      ),
                      _buildNutrientBadge(
                        Icons.water_drop,
                        Colors.yellow.shade700,
                        'Fat',
                        meal.getTotalNutrient('Fat'),
                      ),
                      _buildNutrientBadge(
                        Icons.breakfast_dining,
                        Colors.brown,
                        'Carbs',
                        meal.getTotalNutrient('Carbohydrates'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientBadge(IconData icon, Color color, String label, double value) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}g',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(String nutrient, int value) {
    final target = appData.dailyTargets[nutrient] ?? 1;
    final progress = value / target;
    final color = nutrientColors[nutrient]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              nutrient,
              style: GoogleFonts.lato(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$value / $target g',
              style: GoogleFonts.lato(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}
