import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/home_service.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

class HomeProvider extends ChangeNotifier {
  final HomeService _homeService;

  HomeData? _data;
  bool _isLoading = false;
  String? _error;

  HomeProvider({required HomeService homeService})
      : _homeService = homeService;

  HomeData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchHomeData() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _homeService.fetchHomeData();
    } on ApiException catch (e) {
      debugPrint('[HomeProvider] ApiException: ${e.message}');
      _error = e.message;
    } catch (e) {
      debugPrint('[HomeProvider] Error: $e');
      _error = 'Erro ao carregar dados. Tente novamente.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refresh() {
    _data = null;
    unawaited(fetchHomeData());
  }
}
