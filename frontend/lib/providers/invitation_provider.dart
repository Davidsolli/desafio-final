import 'package:flutter/material.dart';
import '../services/invitation_service.dart';
import '../services/api_client.dart';

/// Provider para gerenciar estado de convites de acesso
class InvitationProvider extends ChangeNotifier {
  final InvitationService _invitationService;

  // Estado de validação de código
  String? _validatedCode;
  bool _isValidatingCode = false;
  String? _validationError;

  // Estado de geração de código
  GenerateInvitationResponse? _generatedInvitation;
  bool _isGeneratingCode = false;
  String? _generationError;

  // Estado de listagem de códigos
  ListInvitationsResponse? _myInvitations;
  bool _isLoadingInvitations = false;
  String? _loadingError;

  InvitationProvider({required ApiClient apiClient})
      : _invitationService = InvitationService(apiClient: apiClient);

  // Getters para validação
  String? get validatedCode => _validatedCode;
  bool get isValidatingCode => _isValidatingCode;
  String? get validationError => _validationError;

  // Getters para geração
  GenerateInvitationResponse? get generatedInvitation => _generatedInvitation;
  bool get isGeneratingCode => _isGeneratingCode;
  String? get generationError => _generationError;

  // Getters para listagem
  ListInvitationsResponse? get myInvitations => _myInvitations;
  bool get isLoadingInvitations => _isLoadingInvitations;
  String? get loadingError => _loadingError;

  /// Valida um código de convite
  Future<bool> validateCode(String code) async {
    _isValidatingCode = true;
    _validationError = null;
    _validatedCode = null;
    notifyListeners();

    try {
      final response = await _invitationService.validateCode(code: code);

      if (response.valid) {
        _validatedCode = code;
        return true;
      } else {
        _validationError = response.message;
        return false;
      }
    } catch (e) {
      _validationError = e.toString();
      return false;
    } finally {
      _isValidatingCode = false;
      notifyListeners();
    }
  }

  /// Gera um novo código de convite (apenas PT)
  Future<bool> generateNewCode() async {
    _isGeneratingCode = true;
    _generationError = null;
    _generatedInvitation = null;
    notifyListeners();

    try {
      final response = await _invitationService.generateCode();
      _generatedInvitation = response;
      return true;
    } catch (e) {
      _generationError = e.toString();
      return false;
    } finally {
      _isGeneratingCode = false;
      notifyListeners();
    }
  }

  /// Carrega lista de convites do PT (apenas PT)
  Future<bool> loadMyInvitations() async {
    _isLoadingInvitations = true;
    _loadingError = null;
    notifyListeners();

    try {
      final response = await _invitationService.listMyInvitations();
      _myInvitations = response;
      return true;
    } catch (e) {
      _loadingError = e.toString();
      return false;
    } finally {
      _isLoadingInvitations = false;
      notifyListeners();
    }
  }

  /// Limpa o código validado
  void clearValidatedCode() {
    _validatedCode = null;
    _validationError = null;
    notifyListeners();
  }

  /// Limpa o código gerado
  void clearGeneratedInvitation() {
    _generatedInvitation = null;
    _generationError = null;
    notifyListeners();
  }

  /// Limpa erros de validação
  void clearValidationError() {
    _validationError = null;
    notifyListeners();
  }
}
