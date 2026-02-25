import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/validators.dart';
import 'widgets/cyber_widgets.dart';

//By Reogie Mabawad

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});
  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const Color cyanPrimary = Color(0xFF0DA6F2);
  static const Color pinkAccent = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020408);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final nameErr = Validators.validateName(_nameController.text);
    final emailErr = Validators.validateEmail(_emailController.text);
    final passErr = Validators.validatePassword(_passwordController.text);

    if (nameErr != null || emailErr != null || passErr != null) {
      _showSnackBar(nameErr ?? emailErr ?? passErr!, isError: true);
      return;
    }

    bool success = await authVM.register(_nameController.text, _emailController.text, _passwordController.text);
    if (success) {
      _showSnackBar("Identity Secured. Access Granted.");
    } else {
      _showSnackBar(authVM.errorMessage ?? "Registration Failed", isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : cyanPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthViewModel>().isLoading;

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHexagonLogo(),
                  const SizedBox(height: 30),
                  _buildMainTitle(),
                  const SizedBox(height: 50), // Matched Login spacing
                  _buildLabelRow("FULL NAME", ""),
                  CyberInput(
                    controller: _nameController,
                    hint: "Enter your full name",
                    icon: Icons.badge_outlined,
                    accent: cyanPrimary,
                  ),
                  const SizedBox(height: 25), // Matched Login spacing
                  _buildLabelRow("EMAIL ADDRESS", ""),
                  CyberInput(
                    controller: _emailController,
                    hint: "Enter your email",
                    icon: Icons.email_outlined,
                    accent: cyanPrimary,
                  ),
                  const SizedBox(height: 25), // Matched Login spacing
                  _buildLabelRow("CREATE PASSWORD", "STRENGTH: HIGH"),
                  CyberInput(
                    controller: _passwordController,
                    hint: "Min. 8 characters + Symbol",
                    icon: Icons.lock_outline,
                    accent: pinkAccent,
                    isPassword: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white24, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 40),
                  isLoading 
                    ? const CircularProgressIndicator(color: cyanPrimary)
                    : _buildPrimaryButton("CREATE ACCOUNT", Icons.person_add_alt_1_outlined, onTap: _handleRegister),
                  const SizedBox(height: 50), // Matched Login footer spacing
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pixel-Perfect Copy of Login Shield Icon
  Widget _buildHexagonLogo() => Container(
    padding: const EdgeInsets.all(20), // Matched Login
    decoration: BoxDecoration(
      color: Colors.black, 
      border: Border.all(color: cyanPrimary.withOpacity(0.5), width: 2)
    ),
    child: const Icon(Icons.shield_outlined, color: cyanPrimary, size: 30), // Matched Login
  );

  // Pixel-Perfect Copy of Login Title Styling
  Widget _buildMainTitle() => Column(
    children: [
      RichText(
        text: TextSpan(
          style: GoogleFonts.orbitron(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 3, fontStyle: FontStyle.italic),
          children: const [
            TextSpan(text: "JOIN ", style: TextStyle(color: Colors.white)),
            TextSpan(text: "VAULT", style: TextStyle(color: cyanPrimary)),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text("CREATE NEW IDENTITY", style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 3)),
    ],
  );

  Widget _buildLabelRow(String left, String right) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(left, style: GoogleFonts.spaceGrotesk(color: cyanPrimary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        Text(right, style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  // Pixel-Perfect Copy of Login Primary Button (With the cyber cuts)
  Widget _buildPrimaryButton(String text, IconData icon, {required VoidCallback onTap}) => Container(
    height: 60, width: double.infinity,
    decoration: BoxDecoration(
      color: cyanPrimary.withOpacity(0.1), 
      border: Border.all(color: cyanPrimary.withOpacity(0.5)),
      borderRadius: const BorderRadius.only(topRight: Radius.circular(15), bottomLeft: Radius.circular(15)) // The cyber cut
    ),
    child: InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: GoogleFonts.orbitron(color: cyanPrimary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
          const SizedBox(width: 10),
          Icon(icon, color: cyanPrimary, size: 16),
        ],
      ),
    ),
  );

  Widget _buildFooter(BuildContext context) => InkWell(
    onTap: () => Navigator.pop(context),
    child: RichText(
      text: TextSpan(
        style: GoogleFonts.spaceGrotesk(fontSize: 11, color: Colors.white24, letterSpacing: 0.5),
        children: const [
          TextSpan(text: "Already have an account?  "),
          TextSpan(text: "LOG IN", style: TextStyle(color: pinkAccent, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}