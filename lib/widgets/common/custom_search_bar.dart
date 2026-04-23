import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CustomSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final List<String>? suggestions;

  const CustomSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.suggestions,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _controller = TextEditingController();
  bool _showSuggestions = false;
  List<String> _filtered = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged(value);
    if (widget.suggestions != null && value.isNotEmpty) {
      setState(() {
        _filtered = widget.suggestions!
            .where((s) => s.toLowerCase().contains(value.toLowerCase()))
            .take(5)
            .toList();
        _showSuggestions = _filtered.isNotEmpty;
      });
    } else {
      setState(() => _showSuggestions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textSecondary, size: 18),
                      onPressed: () {
                        _controller.clear();
                        widget.onChanged('');
                        if (widget.onClear != null) widget.onClear!();
                        setState(() => _showSuggestions = false);
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.cardBorder),
              itemBuilder: (_, i) => ListTile(
                dense: true,
                leading: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                title: Text(
                  _filtered[i],
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
                onTap: () {
                  _controller.text = _filtered[i];
                  widget.onChanged(_filtered[i]);
                  setState(() => _showSuggestions = false);
                },
              ),
            ),
          ),
      ],
    );
  }
}
