import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Swipe to Delete Action
/// Provides swipe-to-delete functionality for list items
class SwipeToDelete extends StatelessWidget {
  final Widget child;
  final VoidCallback onDelete;
  final String? confirmMessage;
  final Color? backgroundColor;
  final Color? iconColor;

  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    this.confirmMessage,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (confirmMessage != null) {
          return await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Item'),
              content: Text(confirmMessage!),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: iconColor ?? Colors.white,
        ),
      ),
      child: child,
    );
  }
}

/// Swipe to Archive Action
/// Provides swipe-to-archive functionality for list items
class SwipeToArchive extends StatelessWidget {
  final Widget child;
  final VoidCallback onArchive;
  final Color? backgroundColor;
  final Color? iconColor;

  const SwipeToArchive({
    super.key,
    required this.child,
    required this.onArchive,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onArchive(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF6366F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.archive_rounded,
          color: iconColor ?? Colors.white,
        ),
      ),
      child: child,
    );
  }
}

/// Swipe Actions (Multiple)
/// Provides multiple swipe actions for list items
class SwipeActions extends StatelessWidget {
  final Widget child;
  final List<SwipeAction> actions;

  const SwipeActions({
    super.key,
    required this.child,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        final action = direction == DismissDirection.startToEnd
            ? actions.firstWhere((a) => a.position == SwipePosition.left)
            : actions.firstWhere((a) => a.position == SwipePosition.right);
        action.onTap();
      },
      background: _buildBackground(context, SwipePosition.left),
      secondaryBackground: _buildBackground(context, SwipePosition.right),
      child: child,
    );
  }

  Widget _buildBackground(BuildContext context, SwipePosition position) {
    final action = actions.firstWhere((a) => a.position == position);
    return Container(
      alignment: position == SwipePosition.left
          ? Alignment.centerLeft
          : Alignment.centerRight,
      padding: EdgeInsets.only(
        left: position == SwipePosition.left ? 20 : 0,
        right: position == SwipePosition.right ? 20 : 0,
      ),
      decoration: BoxDecoration(
        color: action.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(action.icon, color: action.iconColor),
          const SizedBox(width: 8),
          Text(
            action.label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: action.iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipe Action Model
class SwipeAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final SwipePosition position;

  SwipeAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = const Color(0xFF6366F1),
    this.iconColor = Colors.white,
    required this.position,
  });
}

/// Swipe Position Enum
enum SwipePosition {
  left,
  right,
}

/// Swipe to Refresh with Actions
/// Combines pull-to-refresh with swipe actions
class SwipeRefreshWithActions extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<SwipeAction> swipeActions;
  final List<Widget> children;

  const SwipeRefreshWithActions({
    super.key,
    required this.onRefresh,
    required this.swipeActions,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFF6366F1),
      child: ListView.builder(
        itemCount: children.length,
        itemBuilder: (context, index) {
          return SwipeActions(
            actions: swipeActions,
            child: children[index],
          );
        },
      ),
    );
  }
}

/// Swipe to Edit Action
/// Provides swipe-to-edit functionality for list items
class SwipeToEdit extends StatelessWidget {
  final Widget child;
  final VoidCallback onEdit;
  final Color? backgroundColor;
  final Color? iconColor;

  const SwipeToEdit({
    super.key,
    required this.child,
    required this.onEdit,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.startToEnd,
      onDismissed: (_) => onEdit(),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: backgroundColor ?? const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.edit_rounded,
          color: iconColor ?? Colors.white,
        ),
      ),
      child: child,
    );
  }
}
