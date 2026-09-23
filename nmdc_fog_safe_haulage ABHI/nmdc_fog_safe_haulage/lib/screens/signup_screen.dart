import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/firestore_service.dart';
import 'dashboard_screen.dart';
import 'admin_home_screen.dart';

class SignupScreen extends StatefulWidget {
  final String? selectedRole;
  const SignupScreen({super.key, this.selectedRole});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const Color bg = Color(0xFF06121F);
  static const Color card = Color(0xFF101F30);
  static const Color border = Color(0xFF29435D);
  static const Color blue = Color(0xFF2F80ED);
  static const Color textMuted = Color(0xFF9AAABD);

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool agree = false;
  bool isLoading = false;

  late String selectedRole;

  @override
  void initState() {
    super.initState();
    selectedRole = widget.selectedRole ?? 'Choose your role';
  }

  final TextEditingController fullNameController =
      TextEditingController();

  final TextEditingController employeeIdController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    fullNameController.dispose();
    employeeIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void showMessage(
    String message, {
    bool error = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            error ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> createAccount() async {
    final fullName = fullNameController.text.trim();
    final employeeId = employeeIdController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword =
        confirmPasswordController.text.trim();

    if (fullName.isEmpty ||
        employeeId.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    if (selectedRole == 'Choose your role') {
      showMessage('Please select your role');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Passwords do not match');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }

    if (!agree) {
      showMessage(
        'Please accept Terms & Conditions',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(
        fullName,
      );

      // Create Firestore Profile
      if (credential.user != null) {
        final profile = UserProfile(
          uid: credential.user!.uid,
          fullName: fullName,
          email: email,
          employeeId: employeeId,
          role: selectedRole,
          status: 'pending',
          approved: false,
          createdAt: DateTime.now(),
        );
        await FirestoreService().createUserProfile(profile);
      }

      if (mounted) {
        showMessage(
          'Account created successfully!',
          error: false,
        );

        Widget nextScreen = const DashboardScreen();
        if (selectedRole == 'Admin' || selectedRole == 'Safety Officer') {
          nextScreen = const AdminHomeScreen();
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => nextScreen),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showMessage(
          'Account already exists. Please Sign In.',
        );

        if (mounted) {
          await Future.delayed(
            const Duration(seconds: 2),
          );

          Navigator.pop(context);
        }
      } else if (e.code == 'invalid-email') {
        showMessage('Invalid email address');
      } else if (e.code == 'weak-password') {
        showMessage(
          'Please choose a stronger password',
        );
      } else {
        showMessage(
          e.message ?? 'Unable to create account',
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < 850;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              Expanded(
                flex: 5,
                child: _leftPanel(),
              ),
            Expanded(
              flex: isMobile ? 1 : 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: 600),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius:
                          BorderRadius.circular(28),
                      border: Border.all(color: border),
                    ),
                    child: _form(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftPanel() {
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
          color: const Color(0xBB06121F),
        ),
        Padding(
          padding: const EdgeInsets.all(38),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.precision_manufacturing,
                    color: Color(0xFF4EA5FF),
                    size: 42,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'NMDC\nFOG SAFE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _infoCard(
                Icons.psychology,
                'AI Driven',
                'Safety Intelligence',
                Colors.blue,
              ),
              const SizedBox(height: 14),
              _infoCard(
                Icons.shield_outlined,
                'Protecting',
                'Lives',
                Colors.green,
              ),
              const SizedBox(height: 14),
              _infoCard(
                Icons.trending_up,
                'Enabling',
                'Productivity',
                Colors.orange,
              ),
              const Spacer(),
              const Text(
                '“Safety is not just a priority,\nit is our commitment.”',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xDD132437),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Join the smart mine safety network',
          style: TextStyle(
            color: textMuted,
            fontSize: 15,
          ),
        ),

        const SizedBox(height: 30),

        Row(
          children: [
            Expanded(
              child: _field(
                controller: fullNameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _field(
                controller: employeeIdController,
                label: 'Employee ID',
                hint: 'Enter employee ID',
                icon: Icons.badge_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        _field(
          controller: emailController,
          label: 'Email Address',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 20),

        const Text(
          'Select Role',
          style: TextStyle(color: Colors.white),
        ),

        const SizedBox(height: 8),

        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF132437),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              dropdownColor:
                  const Color(0xFF132437),
              iconEnabledColor: Colors.white,
              style:
                  const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(
                  value: 'Choose your role',
                  child: Text('Choose your role'),
                ),
                DropdownMenuItem(
                  value: 'Driver',
                  child: Text('Driver'),
                ),
                DropdownMenuItem(
                  value: 'Operator',
                  child: Text('Operator'),
                ),
                DropdownMenuItem(
                  value: 'Safety Officer',
                  child: Text('Safety Officer'),
                ),
                DropdownMenuItem(
                  value: 'Admin',
                  child: Text('Admin'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value!;
                });
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            Expanded(
              child: _passwordField(
                controller: passwordController,
                label: 'Password',
                confirm: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _passwordField(
                controller:
                    confirmPasswordController,
                label: 'Confirm Password',
                confirm: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Checkbox(
              value: agree,
              activeColor: blue,
              onChanged: (value) {
                setState(() {
                  agree = value ?? false;
                });
              },
            ),
            const Expanded(
              child: Text(
                'I agree to the Terms & Conditions and Privacy Policy',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        InkWell(
          onTap: isLoading
              ? null
              : createAccount,
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
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                    )
                  : const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(width: 14),
                        Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Already have an account? Sign In',
              style: TextStyle(
                color: Color(0xFF5DA9FF),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style:
              const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: textMuted),
            prefixIcon:
                Icon(icon, color: textMuted),
            filled: true,
            fillColor:
                const Color(0xFF132437),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(blue),
          ),
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool confirm,
  }) {
    final obscure = confirm
        ? obscureConfirmPassword
        : obscurePassword;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style:
              const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter password',
            hintStyle:
                const TextStyle(color: textMuted),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: textMuted,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: textMuted,
              ),
              onPressed: () {
                setState(() {
                  if (confirm) {
                    obscureConfirmPassword =
                        !obscureConfirmPassword;
                  } else {
                    obscurePassword =
                        !obscurePassword;
                  }
                });
              },
            ),
            filled: true,
            fillColor:
                const Color(0xFF132437),
            border: _border(),
            enabledBorder: _border(),
            focusedBorder: _border(blue),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border([
    Color color = border,
  ]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
  }
}