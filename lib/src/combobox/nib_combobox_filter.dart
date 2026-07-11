import 'nib_combobox_option.dart';

/// Default [NibComboboxFilter]: case-insensitive substring match against
/// [NibComboboxOption.label] or [NibComboboxOption.subtitle]. An empty [query]
/// matches everything.
bool defaultComboboxFilter<T>(NibComboboxOption<T> option, String query) {
  if (query.isEmpty) return true;
  final needle = query.toLowerCase();
  if (option.label.toLowerCase().contains(needle)) return true;
  final subtitle = option.subtitle;
  return subtitle != null && subtitle.toLowerCase().contains(needle);
}

/// Filters [options] down to those [filter] accepts for [query], preserving
/// input order.
List<NibComboboxOption<T>> filterOptions<T>(
  List<NibComboboxOption<T>> options,
  String query,
  NibComboboxFilter<T> filter,
) {
  return [
    for (final option in options)
      if (filter(option, query)) option,
  ];
}
