import 'api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class PlanModel {
  final String id;
  final String adminId;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int durationMonths;
  final String? modality;
  final int evaluationsIncluded;
  final bool isActive;
  final DateTime createdAt;

  PlanModel({
    required this.id,
    required this.adminId,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.durationMonths,
    this.modality,
    required this.evaluationsIncluded,
    required this.isActive,
    required this.createdAt,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      adminId: json['admin_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: double.parse(json['price'].toString()),
      currency: json['currency'] as String? ?? 'BRL',
      durationMonths: json['duration_months'] as int,
      modality: json['modality'] as String?,
      evaluationsIncluded: json['evaluations_included'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get durationLabel {
    switch (durationMonths) {
      case 1: return '1 mês';
      case 3: return '3 meses';
      case 6: return '6 meses';
      case 12: return '1 ano';
      default: return '$durationMonths meses';
    }
  }

  String get priceFormatted => 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
}

class SubscriptionModel {
  final String id;
  final String studentId;
  final String planId;
  final String adminId;
  final String status;
  final String? paymentMethod;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final PlanModel? plan;

  SubscriptionModel({
    required this.id,
    required this.studentId,
    required this.planId,
    required this.adminId,
    required this.status,
    this.paymentMethod,
    this.startedAt,
    this.expiresAt,
    required this.createdAt,
    this.plan,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      planId: json['plan_id'] as String,
      adminId: json['admin_id'] as String,
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String?,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      plan: json['plan'] != null ? PlanModel.fromJson(json['plan'] as Map<String, dynamic>) : null,
    );
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
  bool get isCanceledPending => status == 'canceled_pending';
  bool get isExpired => status == 'expired';
  bool get isCanceled => status == 'canceled';
  bool get canRenew => isExpired || isCanceled;

  String get statusLabel {
    switch (status) {
      case 'active': return 'Ativa';
      case 'pending': return 'Pendente';
      case 'expired': return 'Expirada';
      case 'canceled_pending': return 'Cancelando';
      case 'canceled': return 'Cancelada';
      default: return status;
    }
  }

  int get daysRemaining {
    if (expiresAt == null) return 0;
    return expiresAt!.difference(DateTime.now()).inDays;
  }
}

class SubscriptionSummary {
  final int totalActive;
  final int totalPending;
  final int totalCanceled;
  final int totalExpired;
  final double revenueThisMonth;
  final double revenueLastMonth;

  SubscriptionSummary({
    required this.totalActive,
    required this.totalPending,
    required this.totalCanceled,
    required this.totalExpired,
    required this.revenueThisMonth,
    required this.revenueLastMonth,
  });

  factory SubscriptionSummary.fromJson(Map<String, dynamic> json) {
    return SubscriptionSummary(
      totalActive: json['total_active'] as int? ?? 0,
      totalPending: json['total_pending'] as int? ?? 0,
      totalCanceled: json['total_canceled'] as int? ?? 0,
      totalExpired: json['total_expired'] as int? ?? 0,
      revenueThisMonth: double.parse(json['revenue_this_month'].toString()),
      revenueLastMonth: double.parse(json['revenue_last_month'].toString()),
    );
  }
}

class AdminSubscriptionItem {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String planName;
  final double planPrice;
  final String status;
  final String? paymentMethod;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  AdminSubscriptionItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.planName,
    required this.planPrice,
    required this.status,
    this.paymentMethod,
    this.startedAt,
    this.expiresAt,
    required this.createdAt,
  });

  factory AdminSubscriptionItem.fromJson(Map<String, dynamic> json) {
    return AdminSubscriptionItem(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      studentEmail: json['student_email'] as String,
      planName: json['plan_name'] as String,
      planPrice: double.parse(json['plan_price'].toString()),
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String?,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.parse(json['expires_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'active': return 'Ativa';
      case 'pending': return 'Pendente';
      case 'expired': return 'Expirada';
      case 'canceled_pending': return 'Cancelando';
      case 'canceled': return 'Cancelada';
      default: return status;
    }
  }

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending';
}

class CheckoutResponse {
  final String subscriptionId;
  final String checkoutUrl;
  final String externalPaymentId;
  final String status;

  CheckoutResponse({
    required this.subscriptionId,
    required this.checkoutUrl,
    required this.externalPaymentId,
    required this.status,
  });

  factory CheckoutResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutResponse(
      subscriptionId: json['subscription_id'] as String,
      checkoutUrl: json['checkout_url'] as String,
      externalPaymentId: json['external_payment_id'] as String,
      status: json['status'] as String,
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class PaymentService {
  final ApiClient _apiClient;

  PaymentService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<List<PlanModel>> getAvailablePlans() async {
    final response = await _apiClient.get<List<PlanModel>>(
      '/plans',
      fromJson: (data) {
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => PlanModel.fromJson(e))
              .toList();
        }
        return [];
      },
    );
    return response;
  }

  Future<List<PlanModel>> getAdminPlans() async {
    final response = await _apiClient.get<List<PlanModel>>(
      '/admin/plans',
      fromJson: (data) {
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => PlanModel.fromJson(e))
              .toList();
        }
        return [];
      },
    );
    return response;
  }

  Future<PlanModel> createPlan({
    required String name,
    String? description,
    required double price,
    required int durationMonths,
    String? modality,
    int evaluationsIncluded = 0,
  }) async {
    return await _apiClient.post<PlanModel>(
      '/admin/plans',
      body: {
        'name': name,
        'description': ?description,
        'price': price,
        'duration_months': durationMonths,
        'modality': ?modality,
        'evaluations_included': evaluationsIncluded,
      },
      fromJson: (data) => PlanModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<PlanModel> updatePlan(String planId, {
    String? name,
    String? description,
    double? price,
    int? durationMonths,
    bool? isActive,
  }) async {
    return await _apiClient.put<PlanModel>(
      '/admin/plans/$planId',
      body: {
        'name': ?name,
        'description': ?description,
        'price': ?price,
        'duration_months': ?durationMonths,
        'is_active': ?isActive,
      },
      fromJson: (data) => PlanModel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> deletePlan(String planId) async {
    await _apiClient.delete<void>(
      '/admin/plans/$planId',
      fromJson: (_) {},
    );
  }

  Future<CheckoutResponse> createCheckout({
    required String planId,
    required String paymentMethod,
    String? replacementPolicy,
  }) async {
    return await _apiClient.post<CheckoutResponse>(
      '/subscriptions/checkout',
      body: {
        'plan_id': planId,
        'payment_method': paymentMethod,
        'replacement_policy': ?replacementPolicy,
      },
      fromJson: (data) => CheckoutResponse.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<SubscriptionModel?> getCurrentSubscription() async {
    try {
      return await _apiClient.get<SubscriptionModel>(
        '/subscriptions/current',
        fromJson: (data) => SubscriptionModel.fromJson(data as Map<String, dynamic>),
      );
    } on NotFoundException {
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasActiveSubscription() async {
    final sub = await getCurrentSubscription();
    return sub?.isActive ?? false;
  }

  Future<bool> cancelMySubscription() async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        '/subscriptions/cancel',
        body: {},
        fromJson: (data) => data as Map<String, dynamic>,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SubscriptionSummary> getDashboardSummary() async {
    return await _apiClient.get<SubscriptionSummary>(
      '/admin/subscriptions/summary',
      fromJson: (data) => SubscriptionSummary.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<AdminSubscriptionItem>> getDashboardSubscriptions({
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      'status_filter': ?statusFilter,
    };
    return await _apiClient.get<List<AdminSubscriptionItem>>(
      '/admin/subscriptions/dashboard',
      queryParameters: params,
      fromJson: (data) {
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map((e) => AdminSubscriptionItem.fromJson(e))
              .toList();
        }
        return [];
      },
    );
  }

  Future<bool> manualActivate(String subscriptionId) async {
    try {
      await _apiClient.post<Map>(
        '/admin/subscriptions/$subscriptionId/activate',
        body: {},
        fromJson: (data) => data as Map,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> manualCancel(String subscriptionId) async {
    try {
      await _apiClient.post<Map>(
        '/admin/subscriptions/$subscriptionId/cancel',
        body: {},
        fromJson: (data) => data as Map,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changePlan(String subscriptionId, String newPlanId) async {
    try {
      await _apiClient.put<Map>(
        '/admin/subscriptions/$subscriptionId/change-plan',
        body: {'plan_id': newPlanId},
        fromJson: (data) => data as Map,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
