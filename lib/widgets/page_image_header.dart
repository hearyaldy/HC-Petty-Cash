import 'package:flutter/material.dart';

class PageImageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showBackButton;
  final Widget? statusChip;
  final double height;

  const PageImageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showBackButton = true,
    this.statusChip,
    this.height = 210,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/assets/images/app_icon.png'),
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black54],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (showBackButton)
                          leading ??
                              _buildHeaderActionButton(
                                icon: Icons.arrow_back,
                                tooltip: 'Back',
                                onPressed: () => Navigator.of(context).pop(),
                              )
                        else
                          const SizedBox(width: 40),
                        const Spacer(),
                        ...actions,
                      ],
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ?statusChip,
                          if (statusChip != null) const SizedBox(height: 10),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color iconColor = Colors.white,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: iconColor),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.3),
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 40),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color iconColor = Colors.white,
  }) {
    return actionButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      iconColor: iconColor,
    );
  }
}
