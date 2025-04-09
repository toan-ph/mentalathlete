import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentalathlete/constants/colors.dart';
import 'package:mentalathlete/services/supabase_service.dart';
import 'package:mentalathlete/widgets/custom_button.dart';
import 'package:mentalathlete/widgets/custom_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final SupabaseService supabaseService;
  
  const ForgotPasswordScreen({super.key, required this.supabaseService});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;
  bool _showTokenInput = false;

  @override
  void initState() {
    super.initState();
    
    // Fehler aus URL-Parameter prüfen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForErrorParam();
    });
  }
  
  void _checkForErrorParam() {
    final context = this.context;
    final state = GoRouter.of(context).routeInformationProvider.value;
    final uri = Uri.parse(state.uri.toString());
    final errorParam = uri.queryParameters['error'];
    
    if (errorParam != null && errorParam.isNotEmpty) {
      setState(() {
        _errorMessage = Uri.decodeComponent(errorParam);
        // Wenn ein Fehler mit dem Token auftritt, zeigen wir das Token-Eingabefeld an
        if (_errorMessage!.contains('Token') || 
            _errorMessage!.contains('Link') || 
            _errorMessage!.contains('abgelaufen')) {
          _showTokenInput = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.supabaseService.resetPassword(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  // Neue Methode zur manuellen Token-Verwendung
  Future<void> _useManualToken() async {
    if (_tokenController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Bitte gib einen Token ein';
      });
      return;
    }
    
    // Zum Passwort-Reset-Screen mit dem manuell eingegebenen Token navigieren
    // Hinweis: Bei manueller Eingabe haben wir nur den Token, aber keinen Token-Hash
    // Daher wird eine spezielle Fehlerbehandlung im Reset-Screen nötig sein
    GoRouter.of(context).go('/reset-password?token=${_tokenController.text}&type=recovery');
  }

  @override
  Widget build(BuildContext context) {
    // Fehlermeldung aus URI-Parametern abrufen
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final errorFromParams = queryParams['error'];
    
    // Falls eine Fehlermeldung als Parameter übergeben wurde, diese anzeigen
    if (errorFromParams != null && _errorMessage == null && !_emailSent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _errorMessage = Uri.decodeFull(errorFromParams);
        });
        
        // Fehlermeldung als Snackbar anzeigen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Ein Fehler ist aufgetreten'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Passwort vergessen'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon
                    const Icon(
                      Icons.lock_open,
                      size: 80,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 24),
                    
                    if (!_emailSent) ...[
                      // Titel
                      const Text(
                        'Passwort zurücksetzen',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Untertitel
                      const Text(
                        'Gib deine E-Mail-Adresse ein und wir senden dir einen Link zum Zurücksetzen deines Passworts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Fehlermeldung
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // E-Mail-Eingabefeld
                      CustomTextField(
                        controller: _emailController,
                        hintText: 'E-Mail',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _resetPassword,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Bitte gib deine E-Mail-Adresse ein';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Bitte gib eine gültige E-Mail-Adresse ein';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      
                      // Zurücksetzen-Button
                      CustomButton(
                        text: 'Passwort zurücksetzen',
                        onPressed: _resetPassword,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 16),
                      
                      // Login-Link
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Zurück zum Login'),
                      ),
                      
                      // Manuelle Token-Eingabe Option
                      if (_showTokenInput) ...[
                        const SizedBox(height: 32),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Hast du bereits einen Token?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _tokenController,
                          hintText: 'Token aus der E-Mail einfügen',
                          prefixIcon: Icons.vpn_key_outlined,
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _useManualToken,
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Token verwenden',
                          onPressed: _useManualToken,
                          isOutlined: true,
                        ),
                      ],
                    ] else ...[
                      // Erfolgs-Nachricht
                      const Text(
                        'E-Mail gesendet',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: AppColors.success,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Wir haben eine E-Mail an ${_emailController.text} gesendet. Bitte überprüfe dein Postfach und folge den Anweisungen, um dein Passwort zurückzusetzen.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Manuelle Token-Eingabe
                      const Text(
                        'Token manuell eingeben',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Wenn der Link in der E-Mail nicht funktioniert, kannst du den Token hier manuell eingeben:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _tokenController,
                        hintText: 'Token aus der E-Mail einfügen',
                        prefixIcon: Icons.vpn_key_outlined,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _useManualToken,
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Token verwenden',
                        onPressed: _useManualToken,
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => context.go('/sign-in'),
                        child: const Text('Zurück zum Login'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 