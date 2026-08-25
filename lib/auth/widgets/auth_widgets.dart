import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// The rounded dark input field shared by every auth screen (AU03 email
/// sign up, sign in, forgot/reset password) — same gradient-card style
/// already used by onboarding's Personal Info field, just reused here
/// rather than re-invented.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(
              color: errorText != null
                  ? AppColors.ctaStart
                  : AppColors.cardBorder,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            onChanged: onChanged,
            style: AppTextStyles.fieldValue.copyWith(color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hintText,
              hintStyle: AppTextStyles.fieldPlaceholder,
              suffixIcon: suffix,
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.ctaStart,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// A real (visible, tappable, min 44px) "Continue with Google" button —
/// the official 4-color Google "G" mark, the only social-login button
/// this app implements.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.purple,
                    ),
                  )
                else
                  const _GoogleMark(size: 20),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.buttonLabel.copyWith(
                      color: const Color(0xFF1F1F1F),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark({required this.size});
  final double size;

  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
<path fill="#FFC107" d="M43.611,20.083H42V20H24v8h11.303c-1.649,4.657-6.08,8-11.303,8c-6.627,0-12-5.373-12-12
c0-6.627,5.373-12,12-12c3.059,0,5.842,1.154,7.961,3.039l5.657-5.657C34.046,6.053,29.268,4,24,4C12.955,4,4,12.955,4,24
c0,11.045,8.955,20,20,20c11.045,0,20-8.955,20-20C44,22.659,43.862,21.35,43.611,20.083z"/>
<path fill="#FF3D00" d="M6.306,14.691l6.571,4.819C14.655,15.108,18.961,12,24,12c3.059,0,5.842,1.154,7.961,3.039
l5.657-5.657C34.046,6.053,29.268,4,24,4C16.318,4,9.656,8.337,6.306,14.691z"/>
<path fill="#4CAF50" d="M24,44c5.166,0,9.86-1.977,13.409-5.192l-6.19-5.238C29.211,35.091,26.715,36,24,36
c-5.202,0-9.619-3.317-11.283-7.946l-6.522,5.025C9.505,39.556,16.227,44,24,44z"/>
<path fill="#1976D2" d="M43.611,20.083H42V20H24v8h11.303c-0.792,2.237-2.231,4.166-4.087,5.571
c0.001-0.001,0.002-0.001,0.003-0.002l6.19,5.238C36.971,39.205,44,34,44,24
C44,22.659,43.862,21.35,43.611,20.083z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: size, height: size);
}

/// A simple 3-rule password strength checklist (8+ characters / one
/// number / one special character), matching AU03's approved copy. Never
/// blocks submission on its own — real validation happens server-side via
/// Supabase; this is honest, real-time UI feedback only.
class PasswordStrengthChecklist extends StatelessWidget {
  const PasswordStrengthChecklist({super.key, required this.password});
  final String password;

  bool get _hasLength => password.length >= 8;
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(password);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\]').hasMatch(password);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rule(label: '8+ characters', met: _hasLength),
        _Rule(label: 'One number', met: _hasNumber),
        _Rule(label: 'One special character', met: _hasSpecial),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.met});
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: met ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: met ? AppColors.success : AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple star-shaped mascot for AU06 Auth Success — recreated as pure
/// Flutter widgets (a filled star path + a drawn face), matching the
/// approved reference's character without needing a new binary asset.
class StarMascot extends StatelessWidget {
  const StarMascot({super.key, this.size = 140});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size(size, size), painter: _StarPainter()),
          Positioned(
            top: size * 0.36,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _eye(size),
                SizedBox(width: size * 0.14),
                _eye(size),
              ],
            ),
          ),
          Positioned(
            top: size * 0.5,
            child: Container(
              width: size * 0.18,
              height: size * 0.09,
              decoration: BoxDecoration(
                color: const Color(0xFF7A4A00),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(size * 0.09),
                  bottomRight: Radius.circular(size * 0.09),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double size) => Container(
    width: size * 0.06,
    height: size * 0.06,
    decoration: const BoxDecoration(
      color: Color(0xFF3A2200),
      shape: BoxShape.circle,
    ),
  );
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.gold, Color(0xFFFFA726)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    const points = 5;
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius * 0.5;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi / points) - math.pi / 2;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
