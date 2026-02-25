import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    setState(() { _loading = true; _error = null; });
    final error = await _auth.sendPasswordReset(email);
    if (!mounted) return;
    setState(() { _loading = false; _error = error; });
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Check your inbox.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final error = _isLogin
        ? await _auth.signIn(email, password)
        : await _auth.signUp(email, password, name);

    if (!mounted) return;
    setState(() { _loading = false; _error = error; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.track_changes_rounded,
                      size: 56, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 24),
                Text('LifeTrack',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Welcome back!' : 'Create your account',
                    style: const TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 40),

                // Name field (signup only)
                if (!_isLogin) ...[
                  _buildField(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
                  const SizedBox(height: 16),
                ],

                _buildField(_emailCtrl, 'Email', Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isLogin ? 'Login' : 'Create Account',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),

                // Forgot password (login mode only)
                if (_isLogin) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _forgotPassword,
                      child: Text('Forgot Password?',
                          style: TextStyle(
                              color: Theme.of(context).primaryColor.withOpacity(0.8),
                              fontSize: 13)),
                    ),
                  ),
                ] else
                  const SizedBox(height: 16),

                // Toggle login/signup
                TextButton(
                  onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                  child: Text(
                    _isLogin ? "Don't have an account? Sign up" : 'Already have an account? Login',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
