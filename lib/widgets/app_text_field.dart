import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  /// Memaksa gaya terang (light) terlepas dari tema global.
  /// Dipakai pada halaman login yang latar belakangnya selalu putih.
  final bool forceLight;

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
    this.inputFormatters,
    this.maxLength,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.forceLight = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isLocked = widget.readOnly || !widget.enabled;
    final isDark = !widget.forceLight && AppColors.isDark(context);
    final textCol = isDark ? AppColors.darkText : AppColors.textDark;
    final lockedTextCol =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF344054);
    final labelCol = isDark ? AppColors.darkTextSecondary : AppColors.textGrey;
    final lockedLabelCol =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF475467);
    final borderCol = isDark ? AppColors.darkBorder : AppColors.border;
    final focusCol = isDark ? AppColors.primaryDark : AppColors.primary;
    final lockedFill =
        isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF2F4F7);

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLength: widget.maxLength,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      textCapitalization: widget.textCapitalization,
      validator: widget.validator,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: isLocked ? FontWeight.w600 : FontWeight.w500,
        color: isLocked ? lockedTextCol : textCol,
      ),
      decoration: InputDecoration(
        counterText: '',
        labelText: widget.label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isLocked ? lockedLabelCol : labelCol,
        ),
        filled: isLocked || isDark,
        fillColor: isLocked
            ? lockedFill
            : (isDark ? AppColors.darkSurface : Colors.transparent),
        prefixIcon: Icon(
          widget.icon,
          size: 18,
          color: labelCol,
        ),
        suffixIcon: widget.customSuffixIcon ??
            (widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: labelCol,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : (widget.readOnly
                    ? Icon(Icons.lock_outline_rounded, size: 16, color: labelCol)
                    : null)),
        helperText: widget.helperText,
        helperStyle: TextStyle(fontSize: 11, color: labelCol),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: borderCol,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isLocked ? borderCol : focusCol,
            width: isLocked ? 1.0 : 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderCol),
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
