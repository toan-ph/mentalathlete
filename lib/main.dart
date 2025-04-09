import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'package:mentalathlete/screens/forgot_password_screen.dart';
import 'package:mentalathlete/screens/home_screen.dart';
import 'package:mentalathlete/screens/sign_in_screen.dart';
import 'package:mentalathlete/screens/sign_up_screen.dart';
import 'package:mentalathlete/screens/reset_password_screen.dart';
import 'package:mentalathlete/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  try {
    debugPrint('🚀 App wird gestartet...');
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('✅ Flutter Binding initialisiert');
    
    // .env-Datei laden
    await dotenv.load();
    debugPrint('✅ .env-Datei geladen');
    
    // Überprüfen, ob die erforderlichen Umgebungsvariablen vorhanden sind
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception('SUPABASE_URL oder SUPABASE_ANON_KEY fehlt in der .env-Datei');
    }
    
    debugPrint('🔑 Supabase URL: ${supabaseUrl.substring(0, math.min(20, supabaseUrl.length))}...');
    debugPrint('🔑 Supabase Anon Key: ${supabaseAnonKey.substring(0, math.min(20, supabaseAnonKey.length))}...');
    
    // Supabase initialisieren
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: true,
    );
    debugPrint('✅ Supabase mit Debug-Modus initialisiert');
    
    runApp(const MyApp());
    debugPrint('✅ MyApp gestartet');
  } catch (e, stackTrace) {
    debugPrint('❌ Fehler beim Starten der App: $e');
    debugPrint('❌ Stack Trace: $stackTrace');
    
    // Fehlerbehandlung für die Initialisierung
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Fehler beim Starten der App:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final SupabaseClient _client;
  late final SupabaseService _supabaseService;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _client = Supabase.instance.client;
    _supabaseService = SupabaseService(_client);
    
    _router = GoRouter(
      debugLogDiagnostics: true,
      initialLocation: '/',
      redirect: (context, state) async {
        // Debug-Ausgabe
        debugPrint('🔍 Prüfe Redirect für URL: ${state.uri}');
        
        // Supabase Client und Service initialisieren
        final supabaseService = SupabaseService(Supabase.instance.client);
        final uri = state.uri;
        final uriString = uri.toString();
        
        // Überprüfen der URI auf verschiedene Typen
        final isDeepLink = uriString.startsWith('mentalathlete://deeplink');
        final isLoginCallback = uriString.startsWith('mentalathlete://login-callback');
        final isSupabaseUrl = uriString.contains('supabase.co/auth/v1/verify');
        final isAuthCallback = uriString.contains('auth-callback') || uri.queryParameters['type'] == 'google';
        final isResetPassword = uriString.contains('reset-password');
        final isVerification = uriString.contains('verify') || uri.queryParameters['type'] == 'signup';
        
        debugPrint('🧪 URI-Analyse: DeepLink=$isDeepLink, AuthCallback=$isAuthCallback, LoginCallback=$isLoginCallback, SupabaseUrl=$isSupabaseUrl, ResetPW=$isResetPassword, Verify=$isVerification');
        
        // Prüfen, ob wir uns auf der Registrierungsseite befinden und erfolgreich angemeldet sind
        if ((state.matchedLocation == '/register' || state.matchedLocation == '/login') && supabaseService.isAuthenticated) {
          debugPrint('🔐 Benutzer ist bereits angemeldet. Umleitung zur Startseite.');
          return '/';
        }
        
        if (isSupabaseUrl) {
          debugPrint('🔗 Direkter Supabase-Callback erkannt: $uri');
          // Umleitung zur App-URL
          final redirectUrl = Uri.parse(uriString);
          final queryParams = redirectUrl.queryParameters;
          
          // Extrahieren wichtiger Parameter (access_token, refresh_token, etc.)
          debugPrint('🔍 Parameter aus Supabase-Callback:');
          queryParams.forEach((key, value) {
            final displayValue = (key.contains('token')) 
                ? "${value.substring(0, math.min(10, value.length))}..."
                : value;
            debugPrint('   - $key: $displayValue');
          });
          
          final code = queryParams['code'];
          if (code != null && code.isNotEmpty) {
            try {
              debugPrint('🔄 Versuche direkten Code-Austausch von Supabase-URL');
              final response = await _client.auth.exchangeCodeForSession(code);
              debugPrint('✅ Code erfolgreich ausgetauscht: ${response.session.user.email}');
              
              // Kurze Verzögerung für die Session-Aktualisierung
              await Future.delayed(const Duration(milliseconds: 500));
              
              if (supabaseService.isAuthenticated) {
                debugPrint('✅ Anmeldung über Code-Austausch erfolgreich');
                return '/';
              }
            } catch (codeError) {
              debugPrint('❌ Fehler beim direkten Code-Austausch: $codeError');
            }
          }
          
          // Versuche eine Session aus dem URL zu bekommen
          try {
            debugPrint('🔄 Verarbeite Supabase-Callback mit spezialisierter Methode');
            await supabaseService.handleOAuthCallback(uriString);
            
            // Kurze Verzögerung für die Session-Aktualisierung
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Wenn Anmeldung erfolgreich, zur Startseite weiterleiten
            if (supabaseService.isAuthenticated) {
              debugPrint('✅ Anmeldung über Supabase-Callback erfolgreich');
              return '/';
            }
          } catch (e) {
            debugPrint('❌ Fehler bei der Verarbeitung des Supabase-Callbacks: $e');
          }
          
          // Bei Fehler zurück zum Login
          return '/sign-in?error=callback_failed';
        }
        
        // Login-Callback Verarbeitung (z.B. nach Google-Anmeldung)
        if (isLoginCallback) {
          debugPrint('🔗 Login-Callback erkannt: $uri');
          
          try {
            // Versuche, eine Session aus dem Callback abzuleiten
            await supabaseService.handleOAuthCallback(uriString);
            
            // Kurze Verzögerung für die Session-Aktualisierung
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Wenn Anmeldung erfolgreich, zur Startseite weiterleiten
            if (supabaseService.isAuthenticated) {
              debugPrint('✅ Anmeldung über Login-Callback erfolgreich');
              return '/';
            } else {
              debugPrint('⚠️ Login-Callback verarbeitet, aber keine Session gefunden');
              // Prüfen, ob es einen Code-Parameter gibt
              final code = uri.queryParameters['code'];
              if (code != null && code.isNotEmpty) {
                debugPrint('🔑 Code-Parameter gefunden, versuche direkten Austausch');
                try {
                  final response = await _client.auth.exchangeCodeForSession(code);
                  debugPrint('✅ Code-Austausch erfolgreich: ${response.session.user.email}');
                  return '/';
                } catch (codeError) {
                  debugPrint('❌ Code-Austausch fehlgeschlagen: $codeError');
                }
              }
            }
          } catch (e) {
            debugPrint('❌ Fehler bei der Verarbeitung des Login-Callbacks: $e');
          }
          
          // Bei Fehler zurück zum Login
          return '/sign-in?error=oauth_failed';
        }

        // Normale Authentifizierungsprüfung
        final isLoggedIn = supabaseService.isAuthenticated;
        final isGoingToLogin = state.matchedLocation == '/sign-in';
        final isGoingToRegister = state.matchedLocation == '/sign-up';
        final isGoingToReset = state.matchedLocation == '/reset-password';
        final isGoingToForgotPassword = state.matchedLocation == '/forgot-password';
        
        debugPrint('🔍 Router prüft Navigation zu: ${state.matchedLocation}');
        debugPrint('🔑 Authentifizierung: ${isLoggedIn ? "Angemeldet" : "Nicht angemeldet"}');
        debugPrint('🔄 AuthRouten: Login=$isGoingToLogin, Register=$isGoingToRegister, Reset=$isGoingToReset, ForgotPw=$isGoingToForgotPassword');

        // Deep Link Erkennung
        debugPrint('🔗 Router prüft URI: $uriString');

        // Normale Authentifizierungsprüfung
        if (isLoggedIn) {
          // Wenn der Benutzer angemeldet ist, sollte er zu keinen Auth-Screens weitergeleitet werden
          if (isGoingToLogin || isGoingToRegister || isGoingToReset || isGoingToForgotPassword) {
            debugPrint('🔄 Bereits angemeldet, Umleitung zur Startseite');
            return '/';
          }
          // Ansonsten ist er angemeldet und kann überall hin navigieren
          debugPrint('✅ Angemeldeter Benutzer navigiert zu: ${state.matchedLocation}');
          return null;
        } else {
          // Wenn der Benutzer nicht angemeldet ist
          
          // Sollte er zu einem der Auth-Screens gehen, erlauben wir das
          if (isGoingToLogin || isGoingToRegister || isGoingToReset || isGoingToForgotPassword) {
            debugPrint('✅ Nicht angemeldeter Benutzer darf zu Auth-Screen: ${state.matchedLocation}');
            return null; // Keine Umleitung
          }
          
          // Sonst leiten wir zum Login weiter
          debugPrint('🔄 Nicht angemeldet, Umleitung zur Login-Seite');
          return '/sign-in';
        }
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => HomeScreen(supabaseService: _supabaseService),
        ),
        GoRoute(
          path: '/sign-in',
          name: 'sign-in',
          builder: (context, state) => SignInScreen(supabaseService: _supabaseService),
        ),
        GoRoute(
          path: '/sign-up',
          name: 'sign-up',
          builder: (context, state) => SignUpScreen(supabaseService: _supabaseService),
        ),
        GoRoute(
          path: '/forgot-password',
          name: 'forgot-password',
          builder: (context, state) {
            debugPrint('🔧 ForgotPasswordScreen wird erstellt');
            return ForgotPasswordScreen(supabaseService: _supabaseService);
          },
        ),
        GoRoute(
          path: '/reset-password',
          name: 'reset-password',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'] ?? '';
            final tokenHash = state.uri.queryParameters['token_hash'] ?? '';
            final errorMessage = state.uri.queryParameters['error'];
            
            debugPrint('🔑 ResetPasswordScreen wird erstellt mit:');
            debugPrint('🔑 Token: $token');
            debugPrint('🔑 TokenHash: $tokenHash');
            debugPrint('🔑 Error: $errorMessage');
            
            return ResetPasswordScreen(
              token: token,
              tokenHash: tokenHash,
              errorMessage: errorMessage,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mental Athlete',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
