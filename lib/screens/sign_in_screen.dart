import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mentalathlete/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInScreen extends StatefulWidget {
  final SupabaseService supabaseService;
  
  const SignInScreen({super.key, required this.supabaseService});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    
    // Prüfen, ob ein Fehler übergeben wurde (z.B. nach Redirect)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted) return;
      
      // GoRouter-Kontext holen
      final router = GoRouter.of(context);
      final error = router.routeInformationProvider.value.uri.queryParameters['error'];
      
      if (error != null && error.isNotEmpty) {
        debugPrint('❌ Fehler beim Login-Screen: $error');
        
        String errorMessage;
        switch (error) {
          case 'auth_failed':
            errorMessage = 'Authentifizierung fehlgeschlagen. Bitte versuchen Sie es erneut.';
            break;
          case 'oauth_failed':
            errorMessage = 'Anmeldung mit Google fehlgeschlagen. Bitte versuchen Sie es erneut.';
            break;
          case 'callback_failed':
            errorMessage = 'Rückleitung zur App fehlgeschlagen. Bitte versuchen Sie es erneut.';
            break;
          default:
            errorMessage = 'Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.';
        }
        
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.supabaseService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Der Router wird automatisch weitergeleitet, wenn der Benutzer angemeldet ist
      
      // Zusätzliche manuelle Navigation zur Sicherheit
      if (mounted && context.mounted && widget.supabaseService.isAuthenticated) {
        debugPrint('✅ Anmeldung erfolgreich, manuelle Navigation zur Startseite');
        context.go('/');
      }
    } catch (e) {
      setState(() {
        if (e is AuthException) {
          _errorMessage = e.message;
        } else {
          _errorMessage = 'Ein unerwarteter Fehler ist aufgetreten';
        }
      });
      debugPrint('❌ Fehler bei der Anmeldung: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  // Google-Login Handler
  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });
      
      debugPrint('🔄 Starte Google-Anmeldung...');
      // Supabase Service für Google-Anmeldung verwenden
      final supabaseService = SupabaseService(Supabase.instance.client);
      await supabaseService.signInWithGoogle();
      
      // Nach dem Start des OAuth-Flows warten wir einen Moment
      // Die tatsächliche Anmeldung erfolgt beim Redirect zurück zur App
      debugPrint('✅ Google-Anmeldung gestartet - Benutzer wird zum Browser weitergeleitet');
      
      // Kurze Verzögerung, damit der Nutzer sieht, dass etwas passiert
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('❌ Fehler bei der Google-Anmeldung: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Fehler bei der Google-Anmeldung: $e';
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top Wave
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Color(0xFF0E4A4D),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(80),
                bottomRight: Radius.circular(80),
              ),
            ),
            child: const Center(
              child: Image(
                image: AssetImage('assets/logo.png'),
                height: 100,
                width: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Restlicher Inhalt
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 200), // Abstand zur Top Wave
                    const Text(
                      "Anmelden bei Mental Athlete",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Fehlermeldung
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // E-Mail Feld
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'E-Mail-Adresse',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    // Passwort Feld
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Passwort',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Passwort vergessen?
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          context.push('/forgot-password');
                        },
                        child: const Text(
                          'Passwort vergessen?',
                          style: TextStyle(
                            color: Color(0xFF0E4A4D),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Login-Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0E4A4D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Anmelden',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    const Center(child: Text("Oder anmelden mit")),
                    const SizedBox(height: 16),
                    
                    // Social Login-Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _socialButton(Icons.facebook, () {}),
                        const SizedBox(width: 20),
                        _socialButton(Icons.g_mobiledata, _handleGoogleSignIn),
                        const SizedBox(width: 20),
                        _socialButton(Icons.apple, () {}),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Registrieren-Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Noch kein Konto? "),
                        GestureDetector(
                          onTap: () {
                            context.push('/sign-up');
                          },
                          child: const Text(
                            "Registrieren",
                            style: TextStyle(
                              color: Color(0xFF0E4A4D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: _isLoading ? null : onPressed,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          shape: BoxShape.circle,
        ),
        child: icon == Icons.g_mobiledata
            ? const Image(
                image: AssetImage('assets/google.png'),
                height: 24,
                width: 24,
                fit: BoxFit.contain,
              )
            : Icon(
                icon,
                size: 24,
                color: const Color(0xFF0E4A4D),
              ),
      ),
    );
  }
} 