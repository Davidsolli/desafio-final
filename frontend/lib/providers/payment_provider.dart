import 'package:flutter/foundation.dart';
import '../services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _service;

  PaymentProvider({required PaymentService paymentService})
      : _service = paymentService;

  List<PlanModel> _plans = [];
  SubscriptionModel? _currentSubscription;
  SubscriptionSummary? _summary;
  List<AdminSubscriptionItem> _dashboardSubscriptions = [];
  bool _isLoading = false;
  bool _isLoadingSubscription = false;
  bool _isLoadingDashboard = false;
  String? _error;

  List<PlanModel> get plans => _plans;
  SubscriptionModel? get currentSubscription => _currentSubscription;
  SubscriptionSummary? get summary => _summary;
  List<AdminSubscriptionItem> get dashboardSubscriptions => _dashboardSubscriptions;
  bool get isLoading => _isLoading;
  bool get isLoadingSubscription => _isLoadingSubscription;
  bool get isLoadingDashboard => _isLoadingDashboard;
  String? get error => _error;
  bool get hasActiveSub => _currentSubscription?.isActive ?? false;

  Future<void> loadPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plans = await _service.getAvailablePlans();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAdminPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _plans = await _service.getAdminPlans();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCurrentSubscription() async {
    _isLoadingSubscription = true;
    _error = null;
    notifyListeners();

    try {
      _currentSubscription = await _service.getCurrentSubscription();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingSubscription = false;
      notifyListeners();
    }
  }

  Future<CheckoutResponse?> createCheckout({
    required String planId,
    required String paymentMethod,
    String? replacementPolicy,
  }) async {
    try {
      final result = await _service.createCheckout(
        planId: planId,
        paymentMethod: paymentMethod,
        replacementPolicy: replacementPolicy,
      );
      await loadCurrentSubscription();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createPlan({
    required String name,
    String? description,
    required double price,
    required int durationMonths,
    String? modality,
    int evaluationsIncluded = 0,
  }) async {
    try {
      final plan = await _service.createPlan(
        name: name,
        description: description,
        price: price,
        durationMonths: durationMonths,
        modality: modality,
        evaluationsIncluded: evaluationsIncluded,
      );
      _plans = [..._plans, plan];
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePlan(String planId) async {
    try {
      await _service.deletePlan(planId);
      _plans = _plans.where((p) => p.id != planId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePlan(String planId, {
    String? name,
    String? description,
    double? price,
    int? durationMonths,
    bool? isActive,
  }) async {
    try {
      final updatedPlan = await _service.updatePlan(
        planId,
        name: name,
        description: description,
        price: price,
        durationMonths: durationMonths,
        isActive: isActive,
      );
      _plans = _plans.map((p) => p.id == planId ? updatedPlan : p).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadDashboard({String? statusFilter}) async {
    _isLoadingDashboard = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getDashboardSummary(),
        _service.getDashboardSubscriptions(statusFilter: statusFilter),
      ]);
      _summary = results[0] as SubscriptionSummary;
      _dashboardSubscriptions = results[1] as List<AdminSubscriptionItem>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  Future<bool> manualActivate(String subscriptionId) async {
    final success = await _service.manualActivate(subscriptionId);
    if (success) await loadDashboard();
    return success;
  }

  Future<bool> manualCancel(String subscriptionId) async {
    final success = await _service.manualCancel(subscriptionId);
    if (success) await loadDashboard();
    return success;
  }

  Future<bool> cancelMySubscription() async {
    final success = await _service.cancelMySubscription();
    if (success) await loadCurrentSubscription();
    return success;
  }

  Future<bool> changePlan(String subscriptionId, String newPlanId) async {
    final success = await _service.changePlan(subscriptionId, newPlanId);
    if (success) await loadDashboard();
    return success;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
