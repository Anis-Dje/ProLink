import 'package:flutter/material.dart';

/// Material 3 inline-search app bar.
///
/// Behaves like a normal [AppBar] until the user taps the search icon —
/// at which point the title morphs into a [TextField] focused for input.
/// Tapping the close icon clears the query and returns to the title view.
///
/// The owning screen is responsible for actually filtering its data: this
/// widget only owns the text controller and emits changes via
/// [onSearchChanged]. Pass an empty string when the user closes the bar.
///
/// Drop-in replacement for `AppBar` (it implements [PreferredSizeWidget]).
class SearchableAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SearchableAppBar({
    super.key,
    required this.title,
    required this.onSearchChanged,
    this.hintText = 'Search…',
    this.actions,
    this.bottom,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.centerTitle,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  final String title;
  final String hintText;

  /// Fires every time the search query changes. The widget always emits
  /// an empty string when the user closes the search field, so callers
  /// can simply mirror the value into their own state without bothering
  /// to listen for an explicit "close" callback.
  final ValueChanged<String> onSearchChanged;

  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final bool? centerTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  State<SearchableAppBar> createState() => _SearchableAppBarState();
}

class _SearchableAppBarState extends State<SearchableAppBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _searching = true);
    // Request focus on the next frame so the field is built first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
  }

  void _close() {
    _ctrl.clear();
    widget.onSearchChanged('');
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_searching) {
      return AppBar(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        elevation: widget.elevation,
        bottom: widget.bottom,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Close search',
          onPressed: _close,
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.titleMedium,
          cursorColor: theme.appBarTheme.foregroundColor ??
              theme.colorScheme.onSurface,
          decoration: InputDecoration(
            hintText: widget.hintText,
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: widget.onSearchChanged,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Clear',
              onPressed: () {
                _ctrl.clear();
                widget.onSearchChanged('');
                setState(() {});
              },
            ),
        ],
      );
    }
    return AppBar(
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      elevation: widget.elevation,
      bottom: widget.bottom,
      leading: widget.leading,
      automaticallyImplyLeading: widget.automaticallyImplyLeading,
      centerTitle: widget.centerTitle,
      title: Text(widget.title),
      actions: [
        ...?widget.actions,
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: _open,
        ),
      ],
    );
  }
}
