import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../views/login_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  static const Color primaryCyan = Color(0xFF0DA6F2);
  static const Color accentGreen = Color(0xFF00FF9D);
  static const Color accentRed = Color(0xFFFF003C);
  static const Color darkBg = Color(0xFF05080A);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color cardBgDark = Color(0x660F172A);

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context, listen: false);
    final profileVM = Provider.of<ProfileViewModel>(context);

    // --- TRIGGER SYNC & ERRORS ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      profileVM.syncProfileState(authVM.currentUser?.id);
      
      if (profileVM.errorMessage != null) {
        _showErrorSnackBar(context, profileVM);
      }
    });

    final bool isDark = profileVM.isDarkMode;
    final Color scaffoldBg = isDark ? darkBg : lightBg;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? Colors.white38 : Colors.black45;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.05 : 0.2,
              child: CustomPaint(painter: GridPainter(color: isDark ? Colors.white : Colors.black12)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark, textColor),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 30),
                        _buildUserHero(context, profileVM, isDark, textColor, subTextColor),
                        const SizedBox(height: 40),
                        _buildSectionHeader("Security"),
                        _buildDataCard([
                          _buildSwitchRow(
                            "Biometric Access",
                            "Fingerprint/FaceID enrollment",
                            profileVM.biometricEnabled,
                            isDark, textColor, subTextColor,
                            () => profileVM.toggleBiometricSupport(!profileVM.biometricEnabled, authVM.currentUser?.id),
                          ),
                        ], isDark),
                        const SizedBox(height: 30),
                        _buildSectionHeader("Appearance"),
                        _buildDataCard([
                          _buildSwitchRow(
                            "Dark Mode",
                            "Toggle system interface",
                            isDark,
                            isDark, textColor, subTextColor,
                            () => profileVM.toggleDarkMode(),
                          ),
                        ], isDark),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildLogoutButton(context, profileVM, isDark),
                ),
              ],
            ),
          ),
          if (profileVM.isLoading) _buildLoader(),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, ProfileViewModel vm) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.errorMessage!, style: GoogleFonts.jetBrainsMono(fontSize: 12)),
        backgroundColor: accentRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
    vm.clearError();
  }

  Widget _buildLoader() {
    return Container(
      color: Colors.black54,
      child: const Center(child: CircularProgressIndicator(color: primaryCyan)),
    );
  }

  // UI Components remain largely the same, but cleaner parameter passing
  Widget _buildHeader(bool isDark, Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("SECURE ACCESS", style: GoogleFonts.spaceGrotesk(color: primaryCyan, fontSize: 10, letterSpacing: 3)),
              Text("MY PROFILE", style: GoogleFonts.jetBrainsMono(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          _buildBadge(isDark),
        ],
      ),
    );
  }

  Widget _buildBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accentGreen.withOpacity(0.1),
        border: Border.all(color: accentGreen.withOpacity(0.3)),
      ),
      child: Text("VERIFIED",
          style: GoogleFonts.jetBrainsMono(
              color: isDark ? accentGreen : Colors.green[700], fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildUserHero(BuildContext context, ProfileViewModel vm, bool isDark, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Container(
          height: 80, width: 80,
          decoration: BoxDecoration(border: Border.all(color: primaryCyan, width: 2), color: isDark ? const Color(0xFF1E293B) : Colors.white),
          child: Center(
            child: Text(vm.getInitials(), style: GoogleFonts.orbitron(color: primaryCyan, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NAME", style: GoogleFonts.jetBrainsMono(color: subTextColor, fontSize: 10)),
              Text(vm.displayName, style: GoogleFonts.jetBrainsMono(color: isDark ? primaryCyan : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          // Use your custom 'email' getter which performs the deep search for Google/Facebook
                Text(
                  vm.email, 
                  style: GoogleFonts.jetBrainsMono(
                    color: isDark ? Colors.white70 : Colors.black87, 
                    fontSize: 11
                  )
                ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _showEditDialog(context, vm, isDark),
                child: Text("EDIT PROFILE", style: GoogleFonts.jetBrainsMono(color: primaryCyan, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: primaryCyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: primaryCyan.withOpacity(0.1))),
      ],
    );
  }

  Widget _buildDataCard(List<Widget> children, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: isDark ? cardBgDark : Colors.white,
        border: Border.all(color: primaryCyan.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchRow(String title, String subtitle, bool active, bool isDark, Color textColor, Color subTextColor, VoidCallback onToggle) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.jetBrainsMono(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(subtitle, style: GoogleFonts.jetBrainsMono(color: subTextColor, fontSize: 8)),
              ],
            ),
            _simpleSwitch(active, isDark),
          ],
        ),
      ),
    );
  }

  Widget _simpleSwitch(bool active, bool isDark) {
    return Container(
      width: 40, height: 20, padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: isDark ? Colors.black : Colors.grey[300]),
      child: Align(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(width: 14, height: 14, color: active ? primaryCyan : (isDark ? Colors.white24 : Colors.white)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, ProfileViewModel vm, bool isDark) {
    return TextButton(
      onPressed: () => _showLogoutConfirmation(context, vm, isDark),
      child: Text("TERMINATE_SESSION", style: GoogleFonts.jetBrainsMono(color: accentRed.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showLogoutConfirmation(BuildContext context, ProfileViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: const RoundedRectangleBorder(),
        title: Text("CONFIRM TERMINATION", style: GoogleFonts.orbitron(color: accentRed, fontSize: 14)),
        content: Text("Are you sure you want to end the current secure session?", style: GoogleFonts.jetBrainsMono(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              await vm.signOut();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginView()), (route) => false);
            },
            child: const Text("LOGOUT", style: TextStyle(color: accentRed)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ProfileViewModel vm, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: const RoundedRectangleBorder(),
        title: Text("UPDATE NAME", style: GoogleFonts.orbitron(color: primaryCyan, fontSize: 14)),
        content: TextField(
          controller: vm.nameController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(labelText: "FULL NAME", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryCyan))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              final result = await vm.handleUpdateName();
              if (result == UpdateNameResult.success && context.mounted) Navigator.pop(context);
            },
            child: const Text("SAVE", style: TextStyle(color: primaryCyan)),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color.withOpacity(0.2)..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 30) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 30) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}