import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'root_shell.dart';

/// Screen 2: Sign up / Login with email-password fields, Google button,
/// and guest continuation, backed by Supabase Auth.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = true;
  bool _rememberMe = false;
  bool _isSubmitting = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _enterApp() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const RootShell()));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!SupabaseService.isConfigured) {
      _showError(
        'Account access is unavailable while the backend is disconnected.',
      );
      return;
    }
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter both email and password.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isSignUp) {
        await AuthService.signUp(email: email, password: password);
      } else {
        await AuthService.signIn(email: email, password: password);
      }
      _enterApp();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Guests stay local-only: no Supabase session is created (no anonymous
  /// sign-in), so guests have no `auth.uid()` and cannot vote or rate —
  /// enforced server-side by RLS on `public.votes`.
  void _continueAsGuest() {
    _enterApp();
  }

  Future<void> _signInWithGoogle() async {
    if (!SupabaseService.isConfigured) {
      _showError(
        'Account access is unavailable while the backend is disconnected.',
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final started = await AuthService.signInWithGoogle();
      if (!started && mounted) {
        _showError('Could not start Google sign-in.');
      }
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not start Google sign-in. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!SupabaseService.isConfigured) {
      _showError(
        'Account access is unavailable while the backend is disconnected.',
      );
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first.');
      return;
    }
    try {
      await AuthService.resetPassword(email);
      _showError('Password reset email sent.');
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not send the password reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF000000), Color(0xFF241C12)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo_white.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!SupabaseService.isConfigured)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Backend disconnected. You can continue as a guest; '
                        'account features are temporarily unavailable.',
                      ),
                    ),
                  if (!SupabaseService.isConfigured) const SizedBox(height: 16),
                  _buildTabSwitcher(),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting || !SupabaseService.isConfigured
                        ? null
                        : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Email',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    enabled: SupabaseService.isConfigured,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(Icons.mail_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed:
                            _isSubmitting || !SupabaseService.isConfigured
                            ? null
                            : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Password',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    enabled: SupabaseService.isConfigured,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting || !SupabaseService.isConfigured
                        ? null
                        : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isSignUp ? 'Sign Up' : 'Login'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _continueAsGuest,
                      child: const Text('Continue as Guest'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      children: const [
                        TextSpan(text: 'By continuing you agree to our '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton('Sign Up', true)),
          Expanded(child: _tabButton('Login', false)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, bool signUp) {
    final selected = _isSignUp == signUp;
    return GestureDetector(
      onTap: SupabaseService.isConfigured
          ? () => setState(() => _isSignUp = signUp)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
