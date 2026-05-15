import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/openfoodfacts_service.dart';
import '../../theme/app_colors.dart';
import 'barcode_food_confirm_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _isProcessing = false;

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null) return;

    setState(() => _isProcessing = true);

    final product = await OpenFoodFactsService.lookupBarcode(barcode);

    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produto não encontrado. Busque manualmente pelo nome.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BarcodeFoodConfirmScreen(product: product),
      ),
    );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear produto'),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onBarcodeDetected),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Aponte a câmera para o código de barras',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
