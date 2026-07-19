import 'nib_command_action.dart';

/// One display bucket produced by [groupActions]: a run of consecutive
/// actions sharing the same [group] key (`null` for a run of ungrouped
/// actions, rendered without a section header).
typedef NibCommandActionBucket = ({
  String? group,
  List<NibCommandAction> actions,
});

/// Default [NibCommandActionFilter]: case-insensitive substring match
/// against [NibCommandAction.label] or [NibCommandAction.subtitle]. An
/// empty [query] matches everything.
bool defaultCommandActionFilter(NibCommandAction action, String query) {
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  if (action.label.toLowerCase().contains(needle)) return true;
  final subtitle = action.subtitle;
  return subtitle != null && subtitle.toLowerCase().contains(needle);
}

/// Filters [actions] down to those [filter] accepts for [query], preserving
/// input order.
List<NibCommandAction> filterActions(
  List<NibCommandAction> actions,
  String query,
  NibCommandActionFilter filter,
) {
  return [
    for (final action in actions)
      if (filter(action, query)) action,
  ];
}

/// Recursively searches [actions] and their [NibCommandAction.children] for
/// an action with the given [id]. Used to resolve a recent-action id (which
/// may belong to a nested branch, e.g. "Dark" under "Change theme") back to
/// its full [NibCommandAction] for display.
NibCommandAction? findActionById(List<NibCommandAction> actions, String id) {
  for (final action in actions) {
    if (action.id == id) return action;
    if (action.hasChildren) {
      final found = findActionById(action.children, id);
      if (found != null) return found;
    }
  }
  return null;
}

/// Clusters [actions] into consecutive-run buckets by [NibCommandAction.group],
/// preserving first-appearance order. A run of ungrouped actions becomes one
/// `group: null` bucket rather than one bucket per item; the same group key
/// appearing in two separate (non-adjacent) runs produces two buckets.
List<NibCommandActionBucket> groupActions(List<NibCommandAction> actions) {
  final buckets = <NibCommandActionBucket>[];
  for (final action in actions) {
    if (buckets.isNotEmpty && buckets.last.group == action.group) {
      buckets.last.actions.add(action);
    } else {
      buckets.add((group: action.group, actions: [action]));
    }
  }
  return buckets;
}
