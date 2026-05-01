import 'package:flutter/foundation.dart';
import 'package:omniconnect_fitness/services/api_client.dart';
import 'package:omniconnect_fitness/services/home_service.dart';

class HomeProvider extends ChangeNotifier {
  final HomeService _homeService;

  HomeData? _data;
  bool _isLoading = false;
  String? _error;

  HomeProvider({required HomeService homeService}) : _homeService = homeService;

  HomeData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _data != null;

  Future<void> fetchHomeData() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _homeService.fetchHomeData();
    } on UnauthorizedException catch (e) {
      _error = e.message;
    } on NetworkException catch (e) {
      _error = 'Sem conexão: ${e.message}';
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Erro ao carregar dados da Home';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
