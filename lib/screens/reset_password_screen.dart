import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentalathlete/services/supabase_service.dart';
import 'package:mentalathlete/widgets/custom_button.dart';
import 'package:mentalathlete/widgets/custom_text_field.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class ResetPasswordScreen extends StatefulWidget {
  final String token;
  final String tokenHash;
  final String? errorMessage;

  const ResetPasswordScreen({
    super.key,
    required this.token,
    required this.tokenHash,
    this.errorMessage,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late final SupabaseService _supabaseService;
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService(Supabase.instance.client);
    if (widget.errorMessage != null) {
      _errorMessage = widget.errorMessage;
      debugPrint('❌ Fehler von Router empfangen: $_errorMessage');
    }
    
    // Debug-Ausgabe für Token-Daten
    debugPrint('🔐 ResetPasswordScreen initialisiert mit PKCE-Daten:');
    debugPrint('🔑 Token: ${widget.token.isNotEmpty ? "${widget.token.substring(0, math.min(6, widget.token.length))}..." : "leer"}');
    debugPrint('🔑 TokenHash: ${widget.tokenHash.isNotEmpty ? "${widget.tokenHash.substring(0, math.min(10, widget.tokenHash.length))}..." : "leer"}');
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Prüfen, ob wir gültige Token-Daten haben
  bool get _hasValidTokenData => widget.token.isNotEmpty && widget.tokenHash.isNotEmpty;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.token.isEmpty || widget.tokenHash.isEmpty) {
      setState(() {
        _errorMessage = 'Ungültiger oder fehlender Reset-Link. Bitte fordere einen neuen Link an.';
        _isLoading = false;
      });
      debugPrint('❌ Token oder TokenHash ist leer');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔐 PKCE-Flow: Passwort wird mit Token aktualisiert...');
      debugPrint('🔑 Token: ${widget.token.substring(0, math.min(6, widget.token.length))}...');
      debugPrint('🔑 TokenHash: ${widget.tokenHash.substring(0, math.min(10, widget.tokenHash.length))}...');
      
      // Aktuelle E-Mail-Adresse aus User-Objekt holen, falls vorhanden
      final currentUser = Supabase.instance.client.auth.currentUser;
      final email = currentUser?.email;
      if (email != null) {
        debugPrint('✉️ Verwende E-Mail-Adresse: $email');
      }
      
      await _supabaseService.updatePasswordWithToken(
        token: widget.token,
        tokenHash: widget.tokenHash,
        newPassword: _passwordController.text,
        email: email,
      );
      
      debugPrint('✅ Passwort erfolgreich zurückgesetzt');
      setState(() {
        _isSuccess = true;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message}');
      setState(() {
        _errorMessage = 'Fehler: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Fehler beim Aktualisieren des Passworts: $e');
      // Spezifischere Fehlermeldungen für bessere Benutzerfreundlichkeit
      String errorMessage = 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es später erneut.';
      
      if (e.toString().contains('Invalid') || e.toString().contains('ungültig')) {
        errorMessage = 'Der Reset-Link ist ungültig. Bitte fordere einen neuen Link an.';
      } else if (e.toString().contains('expired') || e.toString().contains('abgelaufen')) {
        errorMessage = 'Der Reset-Link ist abgelaufen. Bitte fordere einen neuen Link an.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wenn keine gültigen Token-Daten vorhanden sind, zeige entsprechende Nachricht
    if (!_hasValidTokenData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Passwort zurücksetzen'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage ?? 'Der Reset-Link ist ungültig oder abgelaufen. Bitte fordern Sie einen neuen Link an.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 40),
              CustomButton(
                text: 'Neuen Link anfordern',
                onPressed: () => context.go('/forgot-password'),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go('/sign-in'),
                child: const Text('Zurück zum Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Passwort zurücksetzen'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isSuccess
            ? _buildSuccessMessage()
            : _buildPasswordForm(),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 80,
          ),
          const SizedBox(height: 20),
          const Text(
            'Passwort erfolgreich zurückgesetzt!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            'Sie können sich jetzt mit Ihrem neuen Passwort anmelden.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          CustomButton(
            text: 'Zum Login',
            onPressed: () => context.go('/sign-in'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bitte geben Sie ein neues Passwort ein',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            CustomTextField(
              controller: _passwordController,
              hintText: 'Neues Passwort',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte geben Sie ein Passwort ein';
                }
                if (value.length < 8) {
                  return 'Das Passwort muss mindestens 8 Zeichen lang sein';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _confirmPasswordController,
              hintText: 'Passwort bestätigen',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Bitte bestätigen Sie Ihr Passwort';
                }
                if (value != _passwordController.text) {
                  return 'Die Passwörter stimmen nicht überein';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomButton(
                    text: 'Passwort zurücksetzen',
                    onPressed: _updatePassword,
                  ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.go('/sign-in'),
              child: const Text('Zurück zum Login'),
            ),
          ],
        ),
      ),
    );
  }
} 