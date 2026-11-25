import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savorsync/core/services/api_service.dart';
import 'package:savorsync/core/services/auth_service.dart';
import 'package:savorsync/core/utils/token_storage.dart';
import 'package:savorsync/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userJson = {
  'id': 'user-1',
  'email': 'cuenta@example.test',
  'username': 'cuenta',
  'role': 'foodie',
  'isActive': true,
  'emailVerified': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage();
  });

  test('Google sign-in is unavailable until the server verifies Google identity',
      () async {
    await expectLater(
      AuthService().signInWithGoogle(),
      throwsA(isA<StateError>()),
    );
  });

  test('login stores a session from a valid server response', () async {
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/auth/login');
      handler.resolve(Response(requestOptions: request, data: {
        'token': 'issued-token',
        'tokenType': 'Bearer',
        'expiresInMs': 840000,
        'user': _userJson,
      }));
    }));

    final result = await AuthService(dio: dio).login('cuenta@example.test', 'clave');

    expect(result.user.id, 'user-1');
    expect(result.tokenType, 'Bearer');
    expect(result.expiresInMs, 840000);
    expect(await storage.getToken(), 'issued-token');
  });

  test('restores the identity verified by the session endpoint', () async {
    await storage.saveToken('stored-token');
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/auth/me');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer stored-token');
      handler.resolve(Response(requestOptions: request, data: _userJson));
    }));

    final provider = AuthProvider(authService: AuthService(dio: dio));
    addTearDown(provider.dispose);
    await provider.bootstrap();

    expect(provider.status, AuthStatus.authenticated);
    expect(provider.user?.id, 'user-1');
  });

  test('a rejected session removes the stored token without inventing a user',
      () async {
    await storage.saveToken('revoked-token');
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.reject(_httpError(request, 401));
    }));

    final provider = AuthProvider(authService: AuthService(dio: dio));
    addTearDown(provider.dispose);
    await provider.bootstrap();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.user, isNull);
    expect(await storage.getToken(), isNull);
  });

  test('a service failure preserves the token and permits restoration retry',
      () async {
    await storage.saveToken('stored-token');
    final dio = Dio();
    var available = false;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (!available) {
        handler.reject(_httpError(request, 503));
        return;
      }
      handler.resolve(Response(requestOptions: request, data: _userJson));
    }));

    final provider = AuthProvider(authService: AuthService(dio: dio));
    addTearDown(provider.dispose);
    await provider.bootstrap();

    expect(provider.status, AuthStatus.unavailable);
    expect(provider.user, isNull);
    expect(await storage.getToken(), 'stored-token');

    available = true;
    await provider.bootstrap();
    expect(provider.status, AuthStatus.authenticated);
    expect(provider.user?.id, 'user-1');
  });

  test('logout calls the server and clears local access if revocation fails',
      () async {
    await storage.saveToken('stored-token');
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/auth/logout');
      expect(request.method, 'POST');
      expect(request.headers['Authorization'], 'Bearer stored-token');
      handler.reject(_httpError(request, 503));
    }));

    final provider = AuthProvider(authService: AuthService(dio: dio));
    addTearDown(provider.dispose);
    await provider.logout();

    expect(provider.status, AuthStatus.unauthenticated);
    expect(provider.sessionNotice, contains('no confirmó la revocación'));
    expect(await storage.getToken(), isNull);
  });

  test('a delayed authorization rejection leaves a newer session intact',
      () async {
    await storage.saveToken('old-token');
    final api = ApiService();
    final mock = InterceptorsWrapper(onRequest: (request, handler) async {
      expect(request.headers['Authorization'], 'Bearer old-token');
      await storage.saveToken('new-token');
      handler.reject(_httpError(request, 401), true);
    });
    api.dio.interceptors.add(mock);
    addTearDown(() => api.dio.interceptors.remove(mock));
    api.onUnauthorized = () => fail('La sesión actual no debe descartarse.');
    addTearDown(() => api.onUnauthorized = null);

    await expectLater(api.dio.get('/auth/me'), throwsA(isA<DioException>()));
    expect(await storage.getToken(), 'new-token');
  });
}

DioException _httpError(RequestOptions request, int status) => DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: status),
      type: DioExceptionType.badResponse,
    );
