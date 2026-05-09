import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de resposta de validação de convite
class ValidateInvitationResponse {
  final bool valid;
  final String? code;
  final String message;

  ValidateInvitationResponse({
    required this.valid,
    this.code,
    required this.message,
  });

  factory ValidateInvitationResponse.fromJson(Map<String, dynamic> json) {
    return ValidateInvitationResponse(
      valid: json['valid'] as bool,
      code: json['code'] as String?,
      message: json['message'] as String,
    );
  }
}

/// Modelo de resposta de geração de convite
class GenerateInvitationResponse {
  final String id;
  final String code;
  final String trainerId;
  final bool used;
  final String? usedById;
  final DateTime createdAt;
  final DateTime? usedAt;

  GenerateInvitationResponse({
    required this.id,
    required this.code,
    required this.trainerId,
    required this.used,
    this.usedById,
    required this.createdAt,
    this.usedAt,
  });

  factory GenerateInvitationResponse.fromJson(Map<String, dynamic> json) {
    return GenerateInvitationResponse(
      id: json['id'] as String,
      code: json['code'] as String,
      trainerId: json['trainer_id'] as String,
      used: json['used'] as bool,
      usedById: json['used_by_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      usedAt: json['used_at'] != null ? DateTime.parse(json['used_at'] as String) : null,
    );
  }
}

/// Modelo de resposta de listagem de convites
class ListInvitationsResponse {
  final int total;
  final int pending;
  final int used;
  final List<GenerateInvitationResponse> invitations;

  ListInvitationsResponse({
    required this.total,
    required this.pending,
    required this.used,
    required this.invitations,
  });

  factory ListInvitationsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> invitationsList = json['invitations'] as List<dynamic>? ?? [];
    return ListInvitationsResponse(
      total: json['total'] as int,
      pending: json['pending'] as int,
      used: json['used'] as int,
      invitations: invitationsList
          .map((inv) => GenerateInvitationResponse.fromJson(inv as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Dados do pré-cadastro WhatsApp vinculados ao código de convite
class WhatsAppPrefillResponse {
  final bool found;
  final String? name;
  final String? email;
  final String? phone;

  WhatsAppPrefillResponse({
    required this.found,
    this.name,
    this.email,
    this.phone,
  });

  factory WhatsAppPrefillResponse.fromJson(Map<String, dynamic> json) {
    return WhatsAppPrefillResponse(
      found: json['found'] as bool,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

/// Serviço de convites
///
/// Responsável por:
/// - Validar códigos de convite
/// - Gerar novos códigos (apenas PT)
/// - Listar convites gerados (apenas PT)
class InvitationService {
  final ApiClient _apiClient;

  InvitationService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Valida um código de convite (público, sem autenticação necessária)
  ///
  /// Args:
  ///   code: Código do convite a validar
  ///
  /// Returns:
  ///   ValidateInvitationResponse com valid=true/false
  ///
  /// Throws:
  ///   NetworkException se erro de conexão
  Future<ValidateInvitationResponse> validateCode({
    required String code,
  }) async {
    try {
      final response = await _apiClient.post<ValidateInvitationResponse>(
        '/invitations/validate',
        body: {
          'code': code,
        },
        fromJson: (data) => ValidateInvitationResponse.fromJson(data as Map<String, dynamic>),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Gera um novo código de convite (apenas para PT autenticado)
  ///
  /// Returns:
  ///   GenerateInvitationResponse com o código gerado
  ///
  /// Throws:
  ///   UnauthorizedException se não autenticado
  ///   ForbiddenException se usuário não é PT
  ///   NetworkException se erro de conexão
  Future<GenerateInvitationResponse> generateCode() async {
    try {
      final response = await _apiClient.post<GenerateInvitationResponse>(
        '/invitations',
        body: {},
        fromJson: (data) => GenerateInvitationResponse.fromJson(data as Map<String, dynamic>),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca dados do pré-cadastro WhatsApp vinculados a um código de convite
  ///
  /// Público — não requer autenticação.
  /// Retorna found=false sem lançar exceção quando não há pré-cadastro.
  Future<WhatsAppPrefillResponse> fetchPrefill({required String code}) async {
    try {
      return await _apiClient.get<WhatsAppPrefillResponse>(
        '/invitations/whatsapp-prefill?code=$code',
        fromJson: (data) =>
            WhatsAppPrefillResponse.fromJson(data as Map<String, dynamic>),
      );
    } catch (_) {
      return WhatsAppPrefillResponse(found: false);
    }
  }

  /// Lista todos os convites gerados pelo PT autenticado
  ///
  /// Returns:
  ///   ListInvitationsResponse com estatísticas e lista de convites
  ///
  /// Throws:
  ///   UnauthorizedException se não autenticado
  ///   ForbiddenException se usuário não é PT
  ///   NetworkException se erro de conexão
  Future<ListInvitationsResponse> listMyInvitations() async {
    try {
      final response = await _apiClient.get<ListInvitationsResponse>(
        '/invitations',
        fromJson: (data) => ListInvitationsResponse.fromJson(data as Map<String, dynamic>),
      );

      return response;
    } catch (e) {
      rethrow;
    }
  }
}
