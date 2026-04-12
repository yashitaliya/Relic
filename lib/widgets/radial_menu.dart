import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadialMenu extends StatefulWidget {
  final List<RadialMenuChild> children;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData icon;
  final IconData? activeIcon;
  final double radius;
  final double startAngle; // In degrees
  final double endAngle; // In degrees
  final bool anchorLeft;

  const RadialMenu({
    super.key,
    required this.children,
    this.backgroundColor = const Color(0xFFF37121),
    this.foregroundColor = Colors.white,
    this.icon = Icons.add,
    this.activeIcon = Icons.close,
    this.radius = 120.0,
    this.startAngle = 180.0, // Start from left
    this.endAngle = 270.0, // End at top
    this.anchorLeft = false,
  });

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.radius + 60, // Ensure enough space for items
      height: widget.radius + 60,
      child: Stack(
        alignment: widget.anchorLeft
            ? Alignment.bottomLeft
            : Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // Menu Items
          ...widget.children.asMap().entries.map((entry) {
            final index = entry.key;
            final child = entry.value;
            final count = widget.children.length;

            // Calculate angle for this item
            // If only 1 item, put it in the middle of the range
            final range = widget.endAngle - widget.startAngle;
            final step = count > 1 ? range / (count - 1) : 0.0;
            final angleDeg = widget.startAngle + (index * step);
            final angleRad = angleDeg * (math.pi / 180.0);

            return _RadialMenuItem(
              child: child,
              index: index,
              angle: angleRad,
              radius: widget.radius,
              anchorLeft: widget.anchorLeft,
              controller: _controller,
              totalItems: count,
            );
          }),

          // Main FAB
          Positioned(
            left: widget.anchorLeft ? 0 : null,
            right: widget.anchorLeft ? null : 0,
            bottom: 0,
            child: FloatingActionButton(
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.foregroundColor,
              onPressed: _toggle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: RotationTransition(
                turns: _rotationAnimation,
                child: Icon(
                  _isOpen ? (widget.activeIcon ?? widget.icon) : widget.icon,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialMenuItem extends StatelessWidget {
  final RadialMenuChild child;
  final int index;
  final double angle;
  final double radius;
  final bool anchorLeft;
  final AnimationController controller;
  final int totalItems;

  const _RadialMenuItem({
    required this.child,
    required this.index,
    required this.angle,
    required this.radius,
    required this.anchorLeft,
    required this.controller,
    required this.totalItems,
  });

  @override
  Widget build(BuildContext context) {
    // Staggered animation
    // Items closer to start animate first
    final intervalStart = 0.0 + (index / totalItems) * 0.5;
    final intervalEnd = 0.5 + (index / totalItems) * 0.5;

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutBack),
      reverseCurve: Interval(intervalStart, intervalEnd, curve: Curves.easeIn),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, childWidget) {
        final progress = animation.value;
        final currentRadius = radius * progress;

        // Calculate position relative to bottom-right (FAB center)
        // cos/sin give coordinates on unit circle.
        // We need to offset them because Stack alignment is bottomRight.
        // x = r * cos(theta), y = r * sin(theta)
        // Since 0,0 is bottom-right, we need negative offsets to move left/up

        final x = currentRadius * math.cos(angle);
        final y = currentRadius * math.sin(angle);

        // Determine label position based on angle
        // If x > 0 (right side), label should be on the right
        // If x < 0 (left side), label should be on the left
        // cos(angle) determines x direction.
        // Note: angle is in radians.
        final isRightSide = math.cos(angle) > 0;

        final labelWidget = child.label != null
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  child.label!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2C2C),
                  ),
                ),
              )
            : const SizedBox.shrink();

        final iconWidget = GestureDetector(
          onTap: child.onPressed,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: child.backgroundColor ?? Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (child.backgroundColor ?? Colors.white).withValues(
                    alpha: 0.4,
                  ),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              child.icon,
              color: child.foregroundColor ?? const Color(0xFFF37121),
              size: 20,
            ),
          ),
        );

        return Positioned(
          left: anchorLeft ? x : null,
          right: anchorLeft ? null : -x,
          bottom: -y,
          child: Transform.scale(
            scale: progress,
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: isRightSide
                    ? [
                        iconWidget,
                        if (child.label != null) ...[
                          const SizedBox(width: 8),
                          labelWidget,
                        ],
                      ]
                    : [
                        if (child.label != null) ...[
                          labelWidget,
                          const SizedBox(width: 8),
                        ],
                        iconWidget,
                      ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RadialMenuChild {
  final IconData icon;
  final String? label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const RadialMenuChild({
    required this.icon,
    this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });
}
