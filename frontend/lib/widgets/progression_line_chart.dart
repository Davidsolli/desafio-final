import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressionLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> dataPoints;
  final bool isLoading;
  final bool hasError;

  const ProgressionLineChart({
    Key? key,
    required this.dataPoints,
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
    final maxLoad = _getMaxLoad();
    final minLoad = _getMinLoad();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Evolução de Carga',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    color: Color(0xFF2196F3),
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
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
                          '${value.toInt()} kg',
                          style: TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: (maxLoad - minLoad) / 5,
                ),
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
          SizedBox(height: 16),
          _buildStatistics(),
        ],
      ),
    );
  }

  List<FlSpot> _prepareChartData() {
    return List.generate(
      dataPoints.length,
      (index) {
        final point = dataPoints[index];
        final load = (point['actual_load_kg'] as num?)?.toDouble() ?? 0.0;
        return FlSpot(index.toDouble(), load);
      },
    );
  }

  double _getMaxLoad() {
    if (dataPoints.isEmpty) return 0;
    return dataPoints
        .map((p) => (p['actual_load_kg'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);
  }

  double _getMinLoad() {
    if (dataPoints.isEmpty) return 0;
    return dataPoints
        .map((p) => (p['actual_load_kg'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a < b ? a : b);
  }

  Widget _buildStatistics() {
    final maxLoad = _getMaxLoad();
    final minLoad = _getMinLoad();
    final avgLoad = dataPoints.isNotEmpty
        ? dataPoints
                .map((p) => (p['actual_load_kg'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            dataPoints.length
        : 0.0;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Máxima', '${maxLoad.toStringAsFixed(1)} kg'),
          _buildStatItem('Média', '${avgLoad.toStringAsFixed(1)} kg'),
          _buildStatItem('Mínima', '${minLoad.toStringAsFixed(1)} kg'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
