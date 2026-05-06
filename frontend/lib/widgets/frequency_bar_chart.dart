import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class FrequencyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> dataPoints;
  final String period; // "weekly" ou "monthly"
  final bool isLoading;
  final bool hasError;

  const FrequencyBarChart({
    Key? key,
    required this.dataPoints,
    required this.period,
    this.isLoading = false,
    this.hasError = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    if (hasError || dataPoints.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Complete este exercício mais vezes\npara ver seu progresso',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Preparar dados para o gráfico
    final chartData = _prepareChartData();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period == "weekly" ? "Frequência Semanal" : "Frequência Mensal",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                barGroups: chartData,
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _prepareChartData() {
    return List.generate(
      dataPoints.length,
      (index) {
        final point = dataPoints[index];
        final count = (point['count'] as num?)?.toDouble() ?? 0.0;

        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count,
              color: Color(0xFF4CAF50),
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      },
    );
  }
}
