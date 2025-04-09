import 'package:flutter/material.dart';
import 'package:mentalathlete/constants/colors.dart';
import 'package:mentalathlete/services/supabase_service.dart';
import 'package:mentalathlete/widgets/custom_button.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  final SupabaseService supabaseService;
  
  const HomeScreen({super.key, required this.supabaseService});

  @override
  Widget build(BuildContext context) {
    final user = supabaseService.currentUser;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mental Athlete'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 80,
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Erfolgreich angemeldet!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  'Willkommen, ${user?.email ?? 'Benutzer'}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                
                CustomButton(
                  text: 'Abmelden',
                  onPressed: () async {
                    try {
                      debugPrint('🔑 Abmeldung wird versucht...');
                      await supabaseService.signOut();
                      debugPrint('✅ Abmeldung erfolgreich');
                      
                      // Manuelle Navigation zum Login-Screen mit GoRouter
                      if (context.mounted) {
                        debugPrint('🔄 Manuelle Navigation zum Login-Screen via GoRouter');
                        context.go('/sign-in');
                      }
                    } catch (e) {
                      debugPrint('❌ Fehler bei der Abmeldung: $e');
                      // Benutzer über den Fehler informieren
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fehler bei der Abmeldung: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 