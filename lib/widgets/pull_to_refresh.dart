import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Modern Pull to Refresh Widget
/// Provides consistent pull-to-refresh functionality across the app
class ModernPullToRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? backgroundColor;
  final Color? indicatorColor;

  const ModernPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.backgroundColor,
    this.indicatorColor,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: indicatorColor ?? const Color(0xFF6366F1),
      backgroundColor: backgroundColor ?? Colors.white,
      displacement: 40,
      strokeWidth: 3,
      child: child,
    );
  }
}

/// Custom Refresh Indicator with Animation
class CustomRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const CustomRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<CustomRefreshIndicator> createState() => _CustomRefreshIndicatorState();
}

class _CustomRefreshIndicatorState extends State<CustomRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _controller.repeat();
    
    try {
      await widget.onRefresh();
    } finally {
      _controller.stop();
      _controller.reset();
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFF6366F1),
      backgroundColor: Colors.white,
      child: widget.child,
    );
  }
}

/// Pull to Refresh with Loading State
class PullToRefreshWithLoading extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final bool isLoading;

  const PullToRefreshWithLoading({
    super.key,
    required this.onRefresh,
    required this.child,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: isLoading ? () async {} : onRefresh,
      color: const Color(0xFF6366F1),
      backgroundColor: Colors.white,
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6366F1),
              ),
            )
          : child,
    );
  }
}

/// Smart Refresh Indicator with Last Updated Time
class SmartRefreshIndicator extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final DateTime? lastUpdated;

  const SmartRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.lastUpdated,
  });

  @override
  State<SmartRefreshIndicator> createState() => _SmartRefreshIndicatorState();
}

class _SmartRefreshIndicatorState extends State<SmartRefreshIndicator> {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: const Color(0xFF6366F1),
      backgroundColor: Colors.white,
      child: Column(
        children: [
          if (widget.lastUpdated != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFF8FAFC),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.update_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Updated: ${_formatTime(widget.lastUpdated!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
