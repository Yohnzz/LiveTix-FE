import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final bool enabled;
  final String? helperText;
  final Widget? customSuffixIcon;

  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.readOnly = false,
    this.enabled = true,
    this.helperText,
    this.customSuffixIcon,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.readOnly || !widget.enabled;

    return TextFormField(
      controller: widget.controller,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: isLocked ? FontWeight.w600 : FontWeight.w500,
        color: isLocked ? const Color(0xFF344054) : AppColors.textDark,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isLocked ? const Color(0xFF475467) : AppColors.textGrey,
        ),
        filled: isLocked,
        fillColor: isLocked ? const Color(0xFFF2F4F7) : Colors.transparent,
        prefixIcon: Icon(
          widget.icon,
          size: 18,
          color: isLocked ? const Color(0xFF667085) : AppColors.textGrey,
        ),
        suffixIcon: widget.customSuffixIcon ??
            (widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.textGrey,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : (widget.readOnly
                    ? const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF98A2B3))
                    : null)),
        helperText: widget.helperText,
        helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLocked ? const Color(0xFFD0D5DD) : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLocked ? const Color(0xFFD0D5DD) : AppColors.primary,
            width: isLocked ? 1.0 : 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
