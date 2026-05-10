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

    // Computar uma vez para evitar múltiplas iterações
    final maxLoad = _getMaxLoad();
    final minLoad = _getMinLoad();
    final chartData = _prepareChartData();
    final interval = (maxLoad - minLoad) < 1.0 ? 1.0 : (maxLoad - minLoad) / 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: chartData,
                    isCurved: true,
                    color: const Color(0xFF2196F3),
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final label = _formatDateLabel(value.toInt());
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(label, style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()} kg',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: interval,
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildStatisticsWithValues(context, maxLoad, minLoad),
      ],
    );
  }

  String _formatDateLabel(int index) {
    if (index < 0 || index >= dataPoints.length) return '';
    final raw = dataPoints[index]['session_date'] as String?;
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
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

  Widget _buildStatisticsWithValues(BuildContext context, double maxLoad, double minLoad) {
    final avgLoad = dataPoints.isNotEmpty
        ? dataPoints
                .map((p) => (p['actual_load_kg'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            dataPoints.length
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
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
