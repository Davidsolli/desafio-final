import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';


/// Exceções customizadas para erros da API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String message = 'Não autorizado', int? statusCode})
      : super(
          message: message,
          statusCode: statusCode ?? 401,
        );
}

class NotFoundException extends ApiException {
  NotFoundException({String message = 'Não encontrado', int? statusCode})
      : super(
          message: message,
          statusCode: statusCode ?? 404,
        );
}

class ServerException extends ApiException {
  ServerException({String message = 'Erro no servidor', int? statusCode})
      : super(
          message: message,
          statusCode: statusCode ?? 500,
        );
}

class NetworkException extends ApiException {
  NetworkException({String message = 'Erro de conexão'})
      : super(
          message: message,
          statusCode: null,
        );
}


/// Cliente HTTP para comunicação com a API OmniConnect

///
/// Funcionalidades:
/// - Autenticação com JWT
/// - Error handling centralizado
/// - Logging de requisições/respostas
/// - Timeout automático
class ApiClient {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _apiPrefix = '/api/v1';
  static const String _tokenKey = 'jwt_token';
  static const Duration _timeout = Duration(seconds: 30);

  late SharedPreferences _prefs;
  String? _token;

  /// Inicializa o cliente (deve ser chamado uma vez na startup)
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString(_tokenKey);
  }

  /// Retorna o token armazenado
  String? get token => _token;

  /// Verifica se há token de autenticação
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  /// Salva o token JWT
  Future<void> saveToken(String token) async {
    _token = token;
    await _prefs.setString(_tokenKey, token);
  }

  /// Limpa o token (logout)
  Future<void> clearToken() async {
    _token = null;
    await _prefs.remove(_tokenKey);
  }

  /// Faz requisição GET
  Future<T> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParameters);
      final response = await _executeRequest(
        () => http.get(uri, headers: _getHeaders()).timeout(_timeout),
      );
      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Faz requisição POST
  Future<T> post<T>(
    String endpoint, {
    required dynamic body,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await _executeRequest(
        () => http
            .post(
              uri,
              headers: _getHeaders(),
              body: _encodeBody(body),
            )
            .timeout(_timeout),
      );
      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Faz requisição PUT
  Future<T> put<T>(
    String endpoint, {
    required dynamic body,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await _executeRequest(
        () => http
            .put(
              uri,
              headers: _getHeaders(),
              body: _encodeBody(body),
            )
            .timeout(_timeout),
      );
      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Faz requisição PATCH
  Future<T> patch<T>(
    String endpoint, {
    required dynamic body,
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await _executeRequest(
        () => http
            .patch(
              uri,
              headers: _getHeaders(),
              body: _encodeBody(body),
            )
            .timeout(_timeout),
      );
      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Faz requisição DELETE
  Future<T> delete<T>(
    String endpoint, {
    required T Function(dynamic) fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint);
      final response = await _executeRequest(
        () => http.delete(uri, headers: _getHeaders()).timeout(_timeout),
      );
      return _parseResponse<T>(response, fromJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Constrói a URI completa
  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullPath = '$_baseUrl$_apiPrefix$path';

    final Map<String, String>? stringParams =
        queryParameters?.map((key, value) => MapEntry(key, value.toString()));

    return Uri.parse(fullPath).replace(queryParameters: stringParams);
  }

  /// Retorna headers padrão com autenticação
  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Adiciona token JWT se disponível
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  /// Codifica o body da requisição
  String _encodeBody(dynamic body) {
    if (body is String) {
      return body;
    }
    return jsonEncode(body);
  }

  /// Executa requisição com tratamento de erros
  Future<http.Response> _executeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      _logResponse(response);

      // Se token expirou, limpa e lança exceção
      if (response.statusCode == 401 && _token != null) {
        await clearToken();
        throw UnauthorizedException(
          message: 'Token expirado',
          statusCode: 401,
        );
      }

      return response;
    } on http.ClientException catch (e) {
      throw NetworkException(message: 'Erro de conexão: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Converte recursivamente Maps e Lists para tipos Dart tipados.
  ///
  /// No Flutter Web, jsonDecode pode retornar LinkedMap<dynamic, dynamic>
  /// em vez de Map<String, dynamic> para objetos aninhados. Esta função
  /// normaliza toda a estrutura antes de passá-la ao fromJson.
  static dynamic _normalizeJson(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map<MapEntry<String, dynamic>>(
          (e) => MapEntry(e.key.toString(), _normalizeJson(e.value)),
        ),
      );
    }
    if (value is List) {
      return value.map<dynamic>(_normalizeJson).toList();
    }
    return value;
  }

  /// Faz parsing da resposta
  T _parseResponse<T>(
    http.Response response,
    T Function(dynamic) fromJson,
  ) {
    final statusCode = response.statusCode;

    // Success (2xx)
    if (statusCode >= 200 && statusCode < 300) {
      try {
        if (response.body.isEmpty) {
          return fromJson({});
        }
        final data = _normalizeJson(jsonDecode(response.body));
        return fromJson(data);
      } catch (e) {
        throw ApiException(
          message: 'Erro ao parsear resposta',
          statusCode: statusCode,
          originalError: e,
        );
      }
    }

    // Client errors (4xx)
    if (statusCode >= 400 && statusCode < 500) {
      final message = _extractErrorMessage(response.body);

      if (statusCode == 401) {
        throw UnauthorizedException(
          message: message,
          statusCode: statusCode,
        );
      }

      if (statusCode == 404) {
        throw NotFoundException(
          message: message,
          statusCode: statusCode,
        );
      }

      throw ApiException(
        message: message,
        statusCode: statusCode,
      );
    }

    // Server errors (5xx)
    if (statusCode >= 500) {
      final message = _extractErrorMessage(response.body);
      throw ServerException(
        message: message,
        statusCode: statusCode,
      );
    }

    throw ApiException(
      message: 'Erro desconhecido',
      statusCode: statusCode,
    );
  }

  /// Extrai mensagem de erro da resposta
  String _extractErrorMessage(String body) {
    try {
      if (body.isEmpty) {
        return 'Erro desconhecido';
      }
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail'] ?? data['message'] ?? 'Erro desconhecido';
    } catch (e) {
      return 'Erro desconhecido';
    }
  }

  /// Log de requisições (apenas em modo debug)
  void _logResponse(http.Response response) {
    // Em produção, desativar logs
    if (const bool.fromEnvironment('dart.vm.product')) {
      return;
    }

    print('[API] ${response.statusCode} ${response.request?.url}');
    if (response.statusCode >= 400) {
      print('[API] Response: ${response.body}');
    }
  }
}
