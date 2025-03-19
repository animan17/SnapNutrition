import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'common_app_bar.dart';
import 'app_data.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class TrackFitnessScreen extends StatefulWidget {
  const TrackFitnessScreen({super.key});

  @override
  TrackFitnessScreenState createState() => TrackFitnessScreenState();  // Public state
}

class TrackFitnessScreenState extends State<TrackFitnessScreen> {
  String selectedMetric = 'Weight';
  final TextEditingController _valueController = TextEditingController();
  final AppData appData = AppData();
  final Map<String, String> metricUnits = {
    'Weight': 'kg',
    'Waist': 'cm',
  };
  Map<String, Map<String, double>> _fitnessData = {};

  @override
  void initState() {
    super.initState();
    print("[DEBUG] TrackFitnessScreen initializing");
    _loadFitnessData();
    // Force initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  Future<void> _loadFitnessData() async {
    setState(() async {
      _fitnessData = await appData.getFitnessHistory();
    });
  }

  void _addEntry() {
    final double? value = double.tryParse(_valueController.text);
    if (value != null) {
      final timestamp = DateTime.now().toIso8601String();
      setState(() {
        appData.addOrUpdateFitnessData(selectedMetric, timestamp, value);
        _valueController.clear();
        _loadFitnessData(); // Reload data after adding new entry
      });
      print("[DEBUG] Added $selectedMetric entry: $value at $timestamp");
    }
  }

  List<FlSpot> _getChartSpots() {
    final entries = appData.getFitnessData(selectedMetric)
      .entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));
    
    if (entries.isEmpty) return [];
    
    if (entries.length == 1) {
      return [FlSpot(5.0, entries.first.value)]; // Center single point
    }

    return entries.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.value,
      );
    }).toList();
  }

  double _getYAxisMax() {
    final entries = appData.getFitnessData(selectedMetric);
    if (entries.isEmpty) return 100; // Default max for empty data
    
    final maxValue = entries.values.reduce((max, value) => 
      value > max ? value : max);
    return (maxValue * 1.2); // Add 20% padding to max value
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("[DEBUG] Building TrackFitnessScreen");
    
    final spots = _getChartSpots();
    final dates = appData.getFitnessData(selectedMetric).keys.toList()..sort();
    final yMax = _getYAxisMax();

    return Scaffold(
      appBar: const CommonAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start, // Changed from spaceBetween
              children: [
                DropdownButton<String>(
                  value: selectedMetric,
                  items: metricUnits.keys.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text('$value (${metricUnits[value]})'),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedMetric = newValue;
                      });
                    }
                  },
                ),
                // Removed Clear Data button
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildMetricChart(selectedMetric),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Enter ${selectedMetric.toLowerCase()} (${metricUnits[selectedMetric]})',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _addEntry,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChart(String metric) {
    if (_fitnessData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final metricData = appData.getFitnessData(metric);
    
    // Sort entries by date
    final sortedEntries = metricData.entries.toList()
      ..sort((a, b) => DateTime.parse(a.key).compareTo(DateTime.parse(b.key)));

    final spots = <FlSpot>[];
    final dates = <String>[];
    
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value));
      dates.add(sortedEntries[i].key);
    }

    final maxY = spots.isEmpty ? 10.0 : spots.map((s) => s.y).reduce(max) * 1.2;

    // Calculate reasonable interval for y-axis
    final maxValue = maxY.ceil();
    final yInterval = (maxValue > 100) ? 50.0 : (maxValue > 50 ? 20.0 : 10.0);

    return Column(
      children: [
        const SizedBox(height: 24),  // Add spacing above chart title
        Text(metric,
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        // Only show labels for exact integer values
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
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true, // Enable curved lines
                    curveSmoothness: 0.35, // Adjust curve smoothness
                    color: Theme.of(context).primaryColor,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Add helper method for month abbreviation (same as in HomeScreen)
  String _getMonthAbbr(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[date.month - 1];
  }
}
