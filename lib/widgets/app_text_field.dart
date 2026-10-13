import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AppTextField({
    super.key,
    required this.label,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      style: const TextStyle(fontSize: 13, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGrey),
        prefixIcon: Icon(widget.icon, size: 18, color: AppColors.textGrey),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18, color: AppColors.textGrey),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
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
