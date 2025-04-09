import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

/// Eine einfache Klasse, die alle Supabase-bezogenen Funktionalitäten kapselt
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Getter für den Supabase-Client
  SupabaseClient get client => _client;

  // Getter für die Authentifizierung
  GoTrueClient get auth => _client.auth;

  // Prüft, ob ein Benutzer angemeldet ist
  bool get isAuthenticated => _client.auth.currentUser != null;

  // Gibt den aktuellen Benutzer zurück
  User? get currentUser => _client.auth.currentUser;

  // Login mit E-Mail und Passwort
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      debugPrint('Fehler beim Anmelden: $e');
      rethrow;
    }
  }

  // Registrieren mit E-Mail und Passwort
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 Registriere Benutzer: $email');
      
      // Explizite App-Callback-URL für die Bestätigung
      final callbackUrl = 'mentalathlete://deeplink/auth-callback?type=signup';
      debugPrint('🔗 Registrierungs-Callback: $callbackUrl');
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: callbackUrl,
        data: {
          'signup_initiated_at': DateTime.now().toIso8601String(),
        }
      );
      
      // Prüfen des Ergebnisses
      if (response.user != null) {
        debugPrint('✅ Registrierung erfolgreich. Benutzer-ID: ${response.user!.id}');
        debugPrint('✉️ Bestätigungs-E-Mail wurde an ${response.user!.email} gesendet.');
        debugPrint('ℹ️ Hinweis: Bitte prüfen Sie den Bestätigungslink in der E-Mail. Er sollte zu "$callbackUrl" weiterleiten.');
      } else {
        debugPrint('⚠️ Registrierung ohne Benutzer abgeschlossen. Prüfen Sie Ihre E-Mails.');
      }
      
      return response;
    } catch (e) {
      debugPrint('❌ Fehler bei der Registrierung: $e');
      rethrow;
    }
  }

  // Abmelden
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Fehler beim Abmelden: $e');
      rethrow;
    }
  }

  // Google-Anmeldung
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('🔄 Google-Anmeldung wird gestartet...');
      // Überprüfen, ob bereits eine Sitzung besteht
      final existingSession = _client.auth.currentSession;
      if (existingSession != null) {
        debugPrint('✅ Bereits angemeldet als: ${existingSession.user.email}');
        return;
      }
      
      // Absolute URL für die Rückleitung zur App erstellen
      // Wichtig: Die URL muss mit dem URL-Schema in der Info.plist übereinstimmen
      const callbackUrl = 'mentalathlete://login-callback';
      debugPrint('🔗 Callback URL: $callbackUrl');
      
      // OAuth Flow starten mit Google als Provider
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: callbackUrl,
        queryParams: {
          // Spezifische Parameter für mobile Weiterleitung
          'skip_http_redirect': 'true',
          'close_window': 'true',
          'close_session': 'true',
        },
        // Externe Anwendung (Safari) statt inAppWebView verwenden
        // Das verbessert die Zuverlässigkeit des automatischen Schließens
        authScreenLaunchMode: LaunchMode.externalApplication
      );
      
      debugPrint('✅ Google-Anmeldung gestartet - Bei erfolgreicher Anmeldung sollte die Weiterleitung zur App erfolgen');
    } catch (e) {
      debugPrint('❌ Fehler bei der Google-Anmeldung: $e');
      rethrow;
    }
  }

  // Passwort zurücksetzen E-Mail senden (PKCE-Flow aktivieren)
  Future<void> resetPassword({required String email}) async {
    try {
      debugPrint('✉️ Sende Passwort-Reset-E-Mail an: $email');
      
      // Link zur App für Redirect nach Passwort-Reset mit spezifischem Pfad
      const redirectUrl = 'mentalathlete://deeplink/reset-password';
      debugPrint('🔐 PKCE-Flow mit Redirect-URL: $redirectUrl');
      
      // Methode zum Senden der Passwort-Reset-E-Mail (PKCE wird automatisch aktiviert)
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );
      
      debugPrint('✅ Passwort-Reset-E-Mail an $email gesendet');
      debugPrint('ℹ️ Hinweis: Der Link in der E-Mail enthält Token und TokenHash Parameter, die für den PKCE-Flow benötigt werden');
    } catch (e) {
      debugPrint('❌ Fehler beim Senden der Passwort-Reset-E-Mail: $e');
      if (e is AuthException) {
        throw Exception('Fehler beim Senden der E-Mail: ${e.message}');
      }
      rethrow;
    }
  }
  
  // Passwort für den angemeldeten Benutzer aktualisieren
  Future<void> updatePassword({required String newPassword}) async {
    try {
      debugPrint('🔍 Aktualisiere Passwort');
      
      final User? user = _client.auth.currentUser;
      if (user == null) {
        debugPrint('❌ Kein angemeldeter Benutzer gefunden');
        throw Exception('Sie müssen angemeldet sein, um Ihr Passwort zu ändern.');
      }
      
      debugPrint('🔍 Benutzer ID: ${user.id}, Email: ${user.email}');
      
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      if (response.user == null) {
        debugPrint('❌ Passwort-Update fehlgeschlagen');
        throw Exception('Das Passwort konnte nicht aktualisiert werden.');
      }
      
      debugPrint('✅ Passwort erfolgreich aktualisiert');
      return;
    } catch (e) {
      debugPrint('❌ Fehler beim Aktualisieren des Passworts: $e');
      if (e.toString().contains('Password should be at least')) {
        throw Exception('Das Passwort muss mindestens 8 Zeichen lang sein.');
      }
      rethrow;
    }
  }

  // Session-Verifizierung für Magic Link und PKCE-Recovery-Flow
  Future<void> verifySession(String url) async {
    try {
      debugPrint('🔍 Verifiziere Session mit URL: $url');
      
      // URL auf wichtige Parameter überprüfen
      final uri = Uri.parse(url);
      debugPrint('🔗 URL-Pfad: ${uri.path}');
      debugPrint('🔗 URL-Schema: ${uri.scheme}');
      debugPrint('🔗 URL-Host: ${uri.host}');
      
      // Parameter extrahieren und anzeigen
      final params = uri.queryParameters;
      debugPrint('🔍 URL Parameter:');
      params.forEach((key, value) {
        final displayValue = (key.contains('token') || key == 'code') 
            ? "${value.substring(0, math.min(8, value.length))}..." 
            : value;
        debugPrint('   - $key: $displayValue');
      });
      
      // Prüfen auf verschiedene Arten von URLs
      final token = params['token'];
      final tokenHash = params['token_hash'];
      final code = params['code'];
      final type = params['type'];
      
      // Google Anmeldung
      if (type == 'google') {
        debugPrint('🔐 Google-Authentifizierung erkannt');
        
        try {
          // Bei Google müssen wir prüfen, ob bereits eine gültige Session existiert
          final session = _client.auth.currentSession;
          if (session != null) {
            debugPrint('✅ Google-Authentifizierung erfolgreich, Session gefunden');
            return;
          }
          
          // Falls ein Code in der URL vorhanden ist, versuchen wir diesen zu verwenden
          if (code != null) {
            debugPrint('🔑 Google Auth-Code gefunden, versuche Code-Austausch');
            final response = await _client.auth.exchangeCodeForSession(code);
            debugPrint('✅ Google-Session erstellt: ${response.session.user.email}');
            return;
          }
        } catch (e) {
          debugPrint('❌ Google-Authentifizierung fehlgeschlagen: $e');
        }
      }
      
      // Fall 1: E-Mail-Verifizierung (Typ: signup, email_change, etc.)
      if (type == 'signup' || type == 'email_change' || uri.path.contains('verify')) {
        debugPrint('🔐 E-Mail-Verifizierung erkannt');
        
        if (token != null) {
          try {
            debugPrint('🔄 Versuche E-Mail-Verifikation mit Token');
            final response = await _client.auth.verifyOTP(
              token: token,
              type: type == 'signup' ? OtpType.signup : OtpType.email,
            );
            
            if (response.session != null) {
              debugPrint('✅ E-Mail-Verifizierung erfolgreich: ${response.user?.id}');
              return;
            }
          } catch (e) {
            debugPrint('❌ E-Mail-Verifizierung fehlgeschlagen: $e');
            
            // Zweiter Versuch mit einem alternativen Typ
            try {
              debugPrint('🔄 Zweiter Versuch mit alternativem OTP-Typ');
              final response = await _client.auth.verifyOTP(
                token: token,
                type: OtpType.email, // Alternativer Typ
              );
              
              if (response.session != null) {
                debugPrint('✅ Alternative E-Mail-Verifizierung erfolgreich');
                return;
              }
            } catch (altError) {
              debugPrint('❌ Zweite E-Mail-Verifizierung fehlgeschlagen: $altError');
            }
          }
        }
      }
      
      // Fall 2: PKCE-Flow (Token und TokenHash für Recovery)
      if (token != null && tokenHash != null && (type == 'recovery' || uri.path.contains('reset-password'))) {
        debugPrint('🔐 PKCE Recovery Flow erkannt');
        
        try {
          // Nur einen der Parameter verwenden, nicht beide gleichzeitig
          final response = await _client.auth.verifyOTP(
            type: OtpType.recovery,
            token: token,
            // tokenHash wird bewusst weggelassen
          );
          
          if (response.session != null) {
            debugPrint('✅ PKCE-OTP verifiziert: ${response.session?.user.id}');
            return;
          }
        } catch (e) {
          debugPrint('❌ PKCE-OTP-Verifikation fehlgeschlagen: $e');
          
          try {
            // Alternative: Nur tokenHash verwenden
            final response = await _client.auth.verifyOTP(
              type: OtpType.recovery,
              tokenHash: tokenHash,
            );
            
            if (response.session != null) {
              debugPrint('✅ PKCE-OTP mit TokenHash verifiziert');
              return;
            }
          } catch (tokenHashError) {
            debugPrint('❌ PKCE-OTP mit TokenHash fehlgeschlagen: $tokenHashError');
          }
        }
      }
      
      // Fall 3: Code Parameter (Magic Link, OAuth Callback)
      if (code != null) {
        debugPrint('🔑 Auth-Code gefunden: ${code.substring(0, math.min(8, code.length))}...');
        
        try {
          // Code für Session austauschen
          final response = await _client.auth.exchangeCodeForSession(code);
          debugPrint('✅ Code ausgetauscht, Session erstellt: ${response.session.user.id}');
          return;
        } catch (e) {
          debugPrint('❌ Fehler beim Austausch des Codes: $e');
        }
      }
      
      // Fallback: Versuche die ganze URL zu verwenden
      try {
        debugPrint('🔍 Versuche getSessionFromUrl mit kompletter URL');
        final AuthSessionUrlResponse response = await _client.auth.getSessionFromUrl(uri);
        debugPrint('✅ Session über URL verifiziert: ${response.session.user.id}');
        return;
      } catch (e) {
        debugPrint('❌ getSessionFromUrl fehlgeschlagen: $e');
        
        // Manuelle Verifizierung der aktuellen Session versuchen
        try {
          final currentSession = _client.auth.currentSession;
          if (currentSession != null) {
            debugPrint('✅ Bestehende Session gefunden: ${currentSession.user.id}');
            return;
          }
        } catch (sessionError) {
          debugPrint('❌ Keine gültige bestehende Session gefunden: $sessionError');
        }
        
        throw Exception('Konnte keine Session aus der URL wiederherstellen: $e');
      }
    } catch (e) {
      debugPrint('❌ Fehler bei der Session-Verifizierung: $e');
      rethrow;
    }
  }

  /// Setzt das Passwort zurück mit einem Token aus einer Reset-E-Mail
  Future<void> updatePasswordWithToken({
    required String newPassword,
    required String token,
    required String tokenHash,
    String? email,
  }) async {
    try {
      debugPrint('🔐 Starte Passwort-Zurücksetzung...');
      debugPrint('🔑 Token: ${token.substring(0, math.min(6, token.length))}...');
      debugPrint('🔑 TokenHash: ${tokenHash.substring(0, math.min(10, tokenHash.length))}...');
      
      // Fehler bei leeren Token-Daten
      if (token.isEmpty || tokenHash.isEmpty) {
        throw Exception('Token oder Token-Hash fehlt. Bitte fordern Sie einen neuen Reset-Link an.');
      }

      // METHODE 1: Nur tokenHash verwenden
      try {
        debugPrint('🔄 Methode 1: Versuche Verifizierung mit tokenHash...');
        final response = await _client.auth.verifyOTP(
          type: OtpType.recovery,
          tokenHash: tokenHash,
          // token wird bewusst weggelassen
        );
        
        if (response.session != null) {
          debugPrint('✅ TokenHash-Verifizierung erfolgreich! User: ${response.session!.user.id}');
          
          // Kleine Verzögerung für die Session-Aktualisierung
          await Future.delayed(const Duration(milliseconds: 500));
          
          final updateResponse = await _client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          
          debugPrint('✅ Passwort erfolgreich aktualisiert für: ${updateResponse.user?.id}');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Methode 1 fehlgeschlagen: $e');
        // Weiter zur nächsten Methode
      }
      
      // METHODE 2: Nur token verwenden
      try {
        debugPrint('🔄 Methode 2: Versuche Verifizierung mit token...');
        final response = await _client.auth.verifyOTP(
          type: OtpType.recovery,
          token: token,
          // tokenHash wird bewusst weggelassen
        );
        
        if (response.session != null) {
          debugPrint('✅ Token-Verifizierung erfolgreich! User: ${response.session!.user.id}');
          
          // Kleine Verzögerung für die Session-Aktualisierung
          await Future.delayed(const Duration(milliseconds: 500));
          
          final updateResponse = await _client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          
          debugPrint('✅ Passwort erfolgreich aktualisiert für: ${updateResponse.user?.id}');
          return;
        }
      } catch (e) {
        debugPrint('⚠️ Methode 2 fehlgeschlagen: $e');
        // Weiter zur nächsten Methode
      }
      
      // METHODE 3: Vollständige URL verwenden
      try {
        debugPrint('🔄 Methode 3: Versuche mit vollständiger Recovery-URL...');
        
        // tokenHash enthält oft ein "pkce_" Präfix, das entfernt werden muss
        final cleanTokenHash = tokenHash.startsWith('pkce_') 
            ? tokenHash.substring(5) 
            : tokenHash;
            
        // URL ohne das "pkce_" Präfix erstellen
        final recoveryUrl = "mentalathlete://deeplink/reset-password?token=$token&token_hash=$cleanTokenHash&type=recovery";
        debugPrint('🔗 Recovery URL: $recoveryUrl');
        
        final response = await _client.auth.getSessionFromUrl(Uri.parse(recoveryUrl));
        
        debugPrint('✅ URL-Session-Verifizierung erfolgreich! User: ${response.session.user.id}');
        
        // Kleine Verzögerung für die Session-Aktualisierung
        await Future.delayed(const Duration(milliseconds: 500));
        
        final updateResponse = await _client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        
        debugPrint('✅ Passwort erfolgreich aktualisiert für: ${updateResponse.user?.id}');
        return;
      } catch (e) {
        debugPrint('⚠️ Methode 3 fehlgeschlagen: $e');
        
        // Spezielle Behandlung für den Fall, dass beide Parameter übergeben wurden
        if (e.toString().contains('Verify requires either a token or a token hash')) {
          // METHODE 4: Alternative OTP-Typen versuchen
          try {
            debugPrint('🔄 Methode 4: Versuche mit alternativem OTP-Typ...');
            final response = await _client.auth.verifyOTP(
              // Alternative Typen probieren
              type: OtpType.email, // Oder OtpType.signup
              token: token,
            );
            
            if (response.session != null) {
              debugPrint('✅ Alternative OTP-Verifizierung erfolgreich!');
              
              final updateResponse = await _client.auth.updateUser(
                UserAttributes(password: newPassword),
              );
              
              debugPrint('✅ Passwort erfolgreich aktualisiert für: ${updateResponse.user?.id}');
              return;
            }
          } catch (altError) {
            debugPrint('⚠️ Methode 4 fehlgeschlagen: $altError');
          }
        }
        
        throw Exception('Alle Verifizierungsmethoden sind fehlgeschlagen. Bitte fordern Sie einen neuen Reset-Link an.');
      }
    } catch (e) {
      debugPrint('❌ Fehler bei der Passwort-Zurücksetzung: $e');
      
      // Spezifischere Fehlermeldungen für verschiedene Szenarien
      if (e.toString().contains('Invalid OTP') || e.toString().contains('Token not found')) {
        throw Exception('Der Reset-Link ist ungültig. Bitte fordern Sie einen neuen an.');
      } else if (e.toString().contains('expired') || e.toString().contains('TokenExpired')) {
        throw Exception('Der Reset-Link ist abgelaufen. Bitte fordern Sie einen neuen an.');
      } else if (e.toString().contains('Password should be')) {
        throw Exception('Das neue Passwort entspricht nicht den Anforderungen. Es sollte mindestens 8 Zeichen lang sein.');
      } else if (e.toString().contains('Verify requires')) {
        throw Exception('Die Überprüfung des Tokens ist fehlgeschlagen. Bitte fordern Sie einen neuen Reset-Link an.');
      } else {
        throw Exception('Fehler beim Zurücksetzen des Passworts: $e');
      }
    }
  }

  // Verarbeitet direkt einen OAuth-Callback-Link (für Google etc.)
  Future<void> handleOAuthCallback(String url) async {
    try {
      debugPrint('🔄 Verarbeite OAuth-Callback: ${url.substring(0, math.min(100, url.length))}...');
      
      // URL parsen und wichtige Parameter extrahieren
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      final isWebUrl = url.contains('https://');
      
      // Wichtige Parameter für Debugging ausgeben
      debugPrint('🔍 OAuth-Callback-Parameter:');
      params.forEach((key, value) {
        final displayValue = (key.contains('token') || key == 'code') 
            ? "${value.substring(0, math.min(8, value.length))}..." 
            : value;
        debugPrint('   - $key: $displayValue');
      });
      
      // Code aus URL extrahieren, falls vorhanden
      final code = params['code'];
      if (code != null && code.isNotEmpty) {
        try {
          debugPrint('🔄 Versuche Code gegen Session zu tauschen...');
          final response = await _client.auth.exchangeCodeForSession(code);
          debugPrint('✅ Code erfolgreich getauscht: ${response.session.user.email}');
          return;
        } catch (codeError) {
          debugPrint('⚠️ Code-Austausch fehlgeschlagen: $codeError');
          // Weitermachen zum nächsten Ansatz
        }
      }
      
      // Fallback: Direkt mit der URL versuchen
      if (isWebUrl) {
        try {
          debugPrint('🔄 Versuche Session aus URL zu extrahieren...');
          final response = await _client.auth.getSessionFromUrl(uri);
          debugPrint('✅ Session aus URL extrahiert: ${response.session.user.email}');
          return;
        } catch (urlError) {
          debugPrint('⚠️ getSessionFromUrl fehlgeschlagen: $urlError');
          // Weitermachen zum nächsten Ansatz
        }
      }

      // Prüfen, ob bereits eine gültige Session existiert (besonders wichtig für OAuth-Flows)
      final currentSession = _client.auth.currentSession;
      if (currentSession != null) {
        debugPrint('✅ Bereits angemeldet mit Session: ${currentSession.user.email}');
        return;
      }
      
      debugPrint('❌ Keine Methode konnte eine gültige Session herstellen');
    } catch (e) {
      debugPrint('❌ Fehler bei der Verarbeitung des OAuth-Callbacks: $e');
      rethrow;
    }
  }
} 