import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'common_app_bar.dart';
import 'app_data.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

class TrackNutritionScreen extends StatefulWidget {
  const TrackNutritionScreen({super.key});

  @override
  TrackNutritionScreenState createState() => TrackNutritionScreenState();
}

class TrackNutritionScreenState extends State<TrackNutritionScreen> {
  final Map<String, Color> nutrientColors = {
    'Protein': Colors.green,
    'Carbohydrates': Colors.orange,
    'Fat': Colors.blue,
  };
  
  Map<String, Map<String, int>> _nutritionHistory = {};
  bool _isLoading = true;

  void loadData() {
    _loadNutritionHistory();
  }

  @override
  void initState() {
    super.initState();
    _loadNutritionHistory();
  }

  Future<void> _loadNutritionHistory() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      final appData = AppData();
      final history = await appData.getNutritionHistory();
      
      if (mounted) {
        setState(() {
          _nutritionHistory = history;
          _isLoading = false;
        });
      }
      print("[DEBUG] TrackNutritionScreen loaded history: $_nutritionHistory");
    } catch (e) {
      print("[ERROR] Failed to load nutrition history: $e");
    }
  }

  void _clearNutritionData() {
    final appData = AppData();
    setState(() {
      appData.clearNutritionData();
      _nutritionHistory.clear();
    });
    print("[DEBUG] Nutrition data cleared");
  }

  Widget _buildNutrientChart(String nutrient, Color color) {
    final appData = AppData();

    print("[DEBUG] Building chart for $nutrient");
    print("[DEBUG] History entries: ${_nutritionHistory.length}");
    print("[DEBUG] Dates available: ${_nutritionHistory.keys.toList()}");

    if (_nutritionHistory.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final sortedEntries = _nutritionHistory.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final spots = <FlSpot>[];
    final dates = <String>[];
    
    for (int i = 0; i < sortedEntries.length; i++) {
      final value = sortedEntries[i].value[nutrient] ?? 0;
      spots.add(FlSpot(i.toDouble(), value.toDouble()));
      dates.add(sortedEntries[i].key);
    }

    print("[DEBUG] Spots: $spots");
    print("[DEBUG] Dates: $dates");

    final dailyTarget = appData.dailyTargets[nutrient] ?? 0;
    final maxY = [
      ...spots.map((s) => s.y),
      dailyTarget.toDouble()
    ].reduce(max) * 1.2;

    final minY = 0.0;
    final range = maxY - minY;
    double yInterval = 10.0;
    if (range > 0) {
      yInterval = (range / 7).ceilToDouble();
      if (yInterval > 100) {
        yInterval = (yInterval / 100).ceil() * 100;
      } else if (yInterval > 50) {
        yInterval = (yInterval / 50).ceil() * 50;
      } else if (yInterval > 20) {
        yInterval = (yInterval / 20).ceil() * 20;
      } else if (yInterval > 10) {
        yInterval = (yInterval / 10).ceil() * 10;
      }
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        Text(nutrient,
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0),
          padding: const EdgeInsets.only(right: 16.0, bottom: 24.0),
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: yInterval,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 == 0) {
                          final index = value.toInt();
                          if (index >= 0 && index < dates.length) {
                            final date = DateTime.parse(dates[index]);
                            return SideTitleWidget(
                              meta: meta,
                              space: 10,
                              angle: -45,
                              child: Text(
                                '${date.day} ${_getMonthAbbr(date)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yInterval,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        if ((value / yInterval) % 2 != 0 && yInterval < 20) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                    axisNameSize: 40,
                  ),
                  topTitles: AxisTitles(axisNameWidget: null),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.grey[600]!,
                    width: 1,
                  ),
                ),
                minX: -0.5,
                maxX: spots.length.toDouble() - 0.5,
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: color,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: dailyTarget.toDouble(),
                      color: Colors.red,
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 5, bottom: 5),
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                        ),
                        labelResolver: (line) => 'Goal: ${line.y.round()}g',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthAbbr(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] Building TrackNutritionScreen");
    
    return Scaffold(
      appBar: CommonAppBar(

      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: _nutritionHistory.isEmpty
                  ? const Center(
                      child: Text('No nutrition data available',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildNutrientChart('Carbohydrates', nutrientColors['Carbohydrates']!),
                          _buildNutrientChart('Protein', nutrientColors['Protein']!),
                          _buildNutrientChart('Fat', nutrientColors['Fat']!),
                        ],
                      ),
                    ),
              ),
            ],
          ),
    );
  }
}
