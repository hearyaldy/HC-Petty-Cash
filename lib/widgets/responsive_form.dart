import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

/// Responsive form layout that adapts to different screen sizes
class ResponsiveForm extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final Widget? actions;
  final EdgeInsets? padding;
  final double maxWidth;

  const ResponsiveForm({
    super.key,
    required this.children,
    this.title,
    this.actions,
    this.padding,
    this.maxWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      maxWidth: maxWidth,
      padding: padding,
      child: Card(
        elevation: ResponsiveHelper.getCardElevation(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveHelper.getBorderRadius(context),
          ),
        ),
        child: Container(
          padding: ResponsiveHelper.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Text(
                  title!,
                  style: ResponsiveHelper.getResponsiveTextTheme(
                    context,
                  ).headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context)),
                Divider(color: Colors.grey.shade300),
                SizedBox(height: ResponsiveHelper.getSpacing(context)),
              ],
              ...children,
              if (actions != null) ...[
                SizedBox(
                  height: ResponsiveHelper.getSpacing(
                    context,
                    mobile: 24,
                    tablet: 32,
                    desktop: 40,
                  ),
                ),
                actions!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive form row that stacks on mobile and arranges in columns on larger screens
class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final List<int>? flex;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.flex,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isMobile(context)) {
      // Stack vertically on mobile
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    } else {
      // Arrange in row on tablet and desktop
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(
              flex: flex != null && i < flex!.length ? flex![i] : 1,
              child: children[i],
            ),
            if (i < children.length - 1) SizedBox(width: spacing),
          ],
        ],
      );
    }
  }
}

/// Responsive text field with consistent styling
class ResponsiveTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final int? maxLines;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final VoidCallback? onTap;
  final bool readOnly;

  const ResponsiveTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.suffixIcon,
    this.prefixIcon,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveHelper.getResponsiveTextTheme(context).labelLarge
              ?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
        ),
        SizedBox(height: ResponsiveHelper.isMobile(context) ? 6 : 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          maxLines: maxLines,
          onTap: onTap,
          style: ResponsiveHelper.getResponsiveTextTheme(context).bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            prefixIcon: prefixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.red.shade600),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
            contentPadding: EdgeInsets.all(
              ResponsiveHelper.isMobile(context) ? 12 : 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Responsive button with consistent styling
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final bool isOutlined;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
    this.textColor,
    this.isOutlined = false,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? Colors.blue.shade600;
    final buttonTextColor =
        textColor ?? (isOutlined ? buttonColor : Colors.white);
    final borderRadius = ResponsiveHelper.getBorderRadius(context);

    Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(buttonTextColor),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: ResponsiveHelper.isMobile(context) ? 18 : 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: ResponsiveHelper.getResponsiveTextTheme(context).labelLarge
              ?.copyWith(fontWeight: FontWeight.w600, color: buttonTextColor),
        ),
      ],
    );

    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: buttonColor,
            side: BorderSide(color: buttonColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 16 : 24,
              vertical: ResponsiveHelper.isMobile(context) ? 12 : 16,
            ),
          ),
          child: buttonChild,
        ),
      );
    } else {
      return SizedBox(
        width: width,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: buttonTextColor,
            elevation: ResponsiveHelper.getCardElevation(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveHelper.isMobile(context) ? 16 : 24,
              vertical: ResponsiveHelper.isMobile(context) ? 12 : 16,
            ),
          ),
          child: buttonChild,
        ),
      );
    }
  }
}

/// Responsive dropdown field
class ResponsiveDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String? Function(T?)? validator;
  final void Function(T?)? onChanged;
  final String? hint;
  final bool enabled;

  const ResponsiveDropdown({
    super.key,
    required this.label,
    required this.items,
    this.value,
    this.validator,
    this.onChanged,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ResponsiveHelper.getResponsiveTextTheme(context).labelLarge
              ?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
        ),
        SizedBox(height: ResponsiveHelper.isMobile(context) ? 6 : 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: enabled ? onChanged : null,
          validator: validator,
          hint: hint != null ? Text(hint!) : null,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveHelper.getBorderRadius(context),
              ),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
            contentPadding: EdgeInsets.all(
              ResponsiveHelper.isMobile(context) ? 12 : 16,
            ),
          ),
        ),
      ],
    );
  }
}
