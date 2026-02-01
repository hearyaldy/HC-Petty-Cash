import 'package:flutter/material.dart';

class DashboardSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;
  final bool initiallyExpanded;
  final bool showBadge;
  final int? badgeCount;
  final VoidCallback? onTap;
  final bool collapsible;

  const DashboardSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.initiallyExpanded = true,
    this.showBadge = false,
    this.badgeCount,
    this.onTap,
    this.collapsible = true,
  });

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsible) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildHeader(), widget.child],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              widget.onTap?.call();
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _buildHeader(),
          ),
          AnimatedCrossFade(
            firstChild: widget.child,
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (widget.iconColor ?? Theme.of(context).primaryColor)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.icon,
              color: widget.iconColor ?? Theme.of(context).primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (widget.showBadge &&
              widget.badgeCount != null &&
              widget.badgeCount! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.badgeCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (widget.collapsible) ...[
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey.shade600,
            ),
          ],
        ],
      ),
    );
  }
}
