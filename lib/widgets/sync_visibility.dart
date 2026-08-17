import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/spacing_utils.dart';
import '../widgets/accessibility_helper.dart';

/// 🔄 Data Sync Visibility with Progress, Animation, Offline Indicator, Conflict Resolution
class SyncVisibilityWidget extends StatefulWidget {
  final bool isSyncing;
  final double syncProgress;
  final bool isOffline;
  final int pendingChanges;
  final int conflictedItems;
  final VoidCallback? onSyncNow;
  final VoidCallback? onResolveConflicts;
  final VoidCallback? onRetrySync;

  const SyncVisibilityWidget({
    super.key,
    this.isSyncing = false,
    this.syncProgress = 0.0,
    this.isOffline = false,
    this.pendingChanges = 0,
    this.conflictedItems = 0,
    this.onSyncNow,
    this.onResolveConflicts,
    this.onRetrySync,
  });

  @override
  State<SyncVisibilityWidget> createState() => _SyncVisibilityWidgetState();
}

class _SyncVisibilityWidgetState extends State<SyncVisibilityWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    if (widget.isSyncing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(SyncVisibilityWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSyncing != oldWidget.isSyncing) {
      if (widget.isSyncing) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOffline) {
      return _buildOfflineIndicator();
    }
    
    if (widget.conflictedItems > 0) {
      return _buildConflictIndicator();
    }
    
    if (widget.isSyncing || widget.pendingChanges > 0) {
      return _buildSyncIndicator();
    }
    
    return _buildSyncedIndicator();
  }

  Widget _buildSyncIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value * 3.14159,
                child: const Icon(
                  Icons.sync,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            widget.isSyncing
                ? 'Syncing ${(widget.syncProgress * 100).toInt()}%'
                : '${widget.pendingChanges} pending',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6366F1),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (widget.pendingChanges > 0 && !widget.isSyncing) ...[
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onSyncNow?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Sync Now',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncedIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Synced',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF10B981),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off,
            size: 16,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Offline',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error,
            size: 16,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${widget.conflictedItems} conflicts',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFEF4444),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onResolveConflicts?.call();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Resolve',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync progress dialog
class SyncProgressDialog extends StatelessWidget {
  final double progress;
  final String currentStep;
  final VoidCallback? onCancel;

  const SyncProgressDialog({
    super.key,
    required this.progress,
    required this.currentStep,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Syncing Data',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${(progress * 100).toInt()}%',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            currentStep,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Conflict resolution dialog
class ConflictResolutionDialog extends StatelessWidget {
  final List<ConflictItem> conflicts;
  final ValueChanged<ConflictItem> onResolveKeepLocal;
  final ValueChanged<ConflictItem> onResolveKeepServer;

  const ConflictResolutionDialog({
    super.key,
    required this.conflicts,
    required this.onResolveKeepLocal,
    required this.onResolveKeepServer,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_rounded, color: const Color(0xFFEF4444)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Data Conflicts',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: conflicts.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final conflict = conflicts[index];
            return _buildConflictItem(conflict);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildConflictItem(ConflictItem conflict) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, size: 16, color: const Color(0xFF6366F1)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  conflict.itemName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Conflict',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFEF4444),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Local version
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_android, size: 12, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'Local (Your Device)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  conflict.localValue,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Server version
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud, size: 12, color: const Color(0xFF6366F1)),
                    const SizedBox(width: 4),
                    Text(
                      'Server (Cloud)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  conflict.serverValue,
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          
          // Resolution buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onResolveKeepLocal(conflict),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Keep Local',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onResolveKeepServer(conflict),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    'Keep Server',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConflictItem {
  final String itemName;
  final String localValue;
  final String serverValue;
  final DateTime localTimestamp;
  final DateTime serverTimestamp;

  ConflictItem({
    required this.itemName,
    required this.localValue,
    required this.serverValue,
    required this.localTimestamp,
    required this.serverTimestamp,
  });
}

/// Offline mode banner
class OfflineModeBanner extends StatelessWidget {
  final bool isOffline;
  final int queuedActions;
  final VoidCallback? onGoOnline;

  const OfflineModeBanner({
    super.key,
    required this.isOffline,
    this.queuedActions = 0,
    this.onGoOnline,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'You\'re Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onGoOnline != null)
                TextButton(
                  onPressed: onGoOnline,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: const Text('Go Online'),
                ),
            ],
          ),
          if (queuedActions > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.queue, color: Colors.white.withValues(alpha: 0.8), size: 14),
                const SizedBox(width: 4),
                Text(
                  '$queuedActions actions queued for sync',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Sync status bar widget
class SyncStatusBar extends StatelessWidget {
  final bool isSyncing;
  final double syncProgress;
  final DateTime? lastSyncTime;
  final VoidCallback? onTap;

  const SyncStatusBar({
    super.key,
    this.isSyncing = false,
    this.syncProgress = 0.0,
    this.lastSyncTime,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final formattedTime = lastSyncTime != null
        ? '${lastSyncTime!.hour}:${lastSyncTime!.minute.toString().padLeft(2, '0')}'
        : 'Never';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.cloud_done,
                size: 14,
                color: const Color(0xFF10B981),
              ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              isSyncing
                  ? 'Syncing ${(syncProgress * 100).toInt()}%'
                  : 'Last synced: $formattedTime',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}