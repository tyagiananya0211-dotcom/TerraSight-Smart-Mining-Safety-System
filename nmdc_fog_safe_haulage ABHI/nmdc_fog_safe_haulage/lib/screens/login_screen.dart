import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'signup_screen.dart';
import 'role_selection_screen.dart';
import '../services/google_auth_service.dart';
import '../services/sso_auth_service.dart';
import 'dashboard_screen.dart';
import 'admin_home_screen.dart';
class LoginScreen extends StatefulWidget {
  final String? selectedRole;
  const LoginScreen({super.key, this.selectedRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscurePassword = true;
  bool rememberMe = false;
  bool isLoading = false;

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  static const Color bg = Color(0xFF06121F);
  static const Color card = Color(0xFF101F30);
  static const Color border = Color(0xFF29435D);
  static const Color blue = Color(0xFF2F80ED);
  static const Color textMuted = Color(0xFF9AAABD);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage('Please enter email and password');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Widget nextScreen = const DashboardScreen();
        if (widget.selectedRole == 'Admin' || widget.selectedRole == 'Safety Officer') {
          nextScreen = const AdminHomeScreen();
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';

      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Incorrect email or password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'network-request-failed') {
        message = 'Internet connection problem';
      }

      showMessage(message);
    } catch (e) {
      showMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() {
      isLoading = true;
    });

    try {
      final credential = await GoogleAuthService().signInWithGoogle(widget.selectedRole);
      if (credential == null) {
        showMessage('Google Sign-In was cancelled or failed.');
      } else {
        if (mounted) {
          Widget nextScreen = const DashboardScreen();
          if (widget.selectedRole == 'Admin' || widget.selectedRole == 'Safety Officer') {
            nextScreen = const AdminHomeScreen();
          }

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => nextScreen),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      showMessage(_authErrorMessage(e));
    } catch (e) {
      showMessage('Google Sign-In failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'operation-not-allowed':
        return 'Sign-in is disabled. Enable the provider in Firebase Authentication.';
      case 'unauthorized-domain':
        return 'This web domain is not authorized for sign-in in Firebase.';
      case 'popup-blocked':
        return 'Sign-in popup was blocked. Allow popups and try again.';
      case 'popup-closed-by-user':
        return 'Sign-in was cancelled.';
      case 'account-exists-with-different-credential':
        return 'This email already uses a different sign-in method.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return error.message ?? 'Sign-in failed (${error.code}).';
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage(
        'Please enter your email first',
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

      showMessage(
        'Password reset email sent successfully',
        error: false,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(
        e.message ?? 'Unable to send reset email',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              Expanded(
                flex: 5,
                child: _buildLeftPanel(),
              ),

            Expanded(
              flex: isMobile ? 1 : 5,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: 470),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius:
                          BorderRadius.circular(28),
                      border: Border.all(
                        color: border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _buildLoginForm(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/screens/assets/images/mine_truck.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: const Color(0xFF0A1928),
            );
          },
        ),

        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xDD06121F),
                Color(0x6606121F),
                Color(0xEE06121F),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(42),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildBrand(),

              const Spacer(),

              const Text(
                'SMART MINE\nSAFETY SYSTEM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'AI-powered fog detection and intelligent\n'
                'haulage safety monitoring.',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 32),

              _feature(
                Icons.shield_outlined,
                'AI Powered Fog Detection',
              ),

              _feature(
                Icons.sensors_outlined,
                'Real-time Monitoring',
              ),

              _feature(
                Icons.notifications_active_outlined,
                'Instant Safety Alerts',
              ),

              _feature(
                Icons.analytics_outlined,
                'Smart Analytics',
              ),

              const Spacer(),

              const Text(
                'AI for Safer Mines. Smarter Operations.',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrand() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: blue.withOpacity(.15),
            shape: BoxShape.circle,
            border: Border.all(color: blue),
          ),
          child: const Icon(
            Icons.precision_manufacturing,
            color: Colors.lightBlueAccent,
            size: 30,
          ),
        ),

        const SizedBox(width: 14),

        const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'NMDC FOG SAFE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            Text(
              'HAULAGE SYSTEM',
              style: TextStyle(
                color: Color(0xFF5DA9FF),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _feature(
    IconData icon,
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF48A7FF),
            size: 28,
          ),

          const SizedBox(width: 16),

          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        if (MediaQuery.of(context).size.width < 800) ...[
          _buildBrand(),
          const SizedBox(height: 45),
        ],

        const Text(
          'Welcome Back! 👋',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          'Sign in to continue to your dashboard',
          style: TextStyle(
            color: textMuted,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 32),

        _label('Email Address'),

        const SizedBox(height: 8),

        TextField(
          controller: emailController,
          keyboardType:
              TextInputType.emailAddress,
          style:
              const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            hintStyle:
                const TextStyle(color: textMuted),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: textMuted,
            ),
            filled: true,
            fillColor:
                const Color(0xFF132437),
            border: _inputBorder(),
            enabledBorder: _inputBorder(),
            focusedBorder:
                _inputBorder(blue),
          ),
        ),

        const SizedBox(height: 22),

        _label('Password'),

        const SizedBox(height: 8),

        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          style:
              const TextStyle(color: Colors.white),
          onSubmitted: (_) {
            if (!isLoading) {
              loginWithEmail();
            }
          },
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle:
                const TextStyle(color: textMuted),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: textMuted,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  obscurePassword =
                      !obscurePassword;
                });
              },
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: textMuted,
              ),
            ),
            filled: true,
            fillColor:
                const Color(0xFF132437),
            border: _inputBorder(),
            enabledBorder: _inputBorder(),
            focusedBorder:
                _inputBorder(blue),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Checkbox(
              value: rememberMe,
              activeColor: blue,
              onChanged: (value) {
                setState(() {
                  rememberMe =
                      value ?? false;
                });
              },
            ),

            const Text(
              'Remember me',
              style: TextStyle(
                color: textMuted,
              ),
            ),

            const Spacer(),

            TextButton(
              onPressed: forgotPassword,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Color(0xFF5DA9FF),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _primaryButton(
          text: isLoading
              ? 'PLEASE WAIT...'
              : 'SIGN IN',
          onTap: isLoading
              ? null
              : loginWithEmail,
        ),

        const SizedBox(height: 28),

        const Row(
          children: [
            Expanded(
              child: Divider(color: border),
            ),

            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or continue with',
                style: TextStyle(
                  color: textMuted,
                ),
              ),
            ),

            Expanded(
              child: Divider(color: border),
            ),
          ],
        ),

        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: _socialButton(
                icon: Icons.g_mobiledata,
                text: 'Google',
                onTap: isLoading
                    ? null
                    : signInWithGoogle,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: _socialButton(
                icon: Icons.security,
                text: 'SSO Login',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(isSsoDemo: true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        Center(
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: textMuted,
                ),
              ),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SignupScreen(selectedRole: widget.selectedRole),
                    ),
                  );
                },
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Color(0xFF5DA9FF),
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
    );
  }

  OutlineInputBorder _inputBorder([
    Color color = border,
  ]) {
    return OutlineInputBorder(
      borderRadius:
          BorderRadius.circular(14),
      borderSide:
          BorderSide(color: color),
    );
  }

  Widget _primaryButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),
      child: Ink(
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF367FF6),
              Color(0xFF1554B8),
            ],
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color:
              const Color(0xFF132437),
          borderRadius:
              BorderRadius.circular(14),
          border:
              Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),

            const SizedBox(width: 8),

            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
