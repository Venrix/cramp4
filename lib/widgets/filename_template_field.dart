import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_menu_style.dart';
import 'hover_text_field.dart';

class TemplatePreset {
  final String label;
  final String value;
  const TemplatePreset(this.label, this.value);
}

/// Shared preset suggestions. Tokens are lowercase (resolution is
/// case-insensitive). The encode tab prepends an "Inherit" entry, see
/// [kEncodeTemplatePresets].
const kFilenameTemplatePresets = <TemplatePreset>[
  TemplatePreset('Default', '{prefix}{filename}{suffix}'),
  TemplatePreset('LosslessCut', '{filename}-{cut_from}-{cut_to}{seg_suffix}{ext}'),
  TemplatePreset(
      'Prefix + resolution + range', '{prefix}{filename}_{res}_{cut_from}-{cut_to}{suffix}'),
  TemplatePreset('Trim range', '{filename}_{cut_from}-{cut_to}'),
  TemplatePreset('With date', '{filename}_{date}'),
  TemplatePreset('With resolution', '{filename}_{res}{suffix}'),
];

/// Encode-tab presets: the default inherits whatever the Settings tab holds.
const kEncodeTemplatePresets = <TemplatePreset>[
  TemplatePreset('Inherit settings template', '{templatedefault}'),
  ...kFilenameTemplatePresets,
];

/// Editable combobox: a free-text [HoverTextField] with a trailing dropdown
/// that fills the field from [presets]. Styled to match the app's other fields.
class FilenameTemplateField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<TemplatePreset> presets;

  const FilenameTemplateField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.presets = kFilenameTemplatePresets,
  });

  @override
  Widget build(BuildContext context) {
    // Match FullWidthDropdown's flyout: background fill, radius 8, anchor width.
    return LayoutBuilder(
      builder: (context, constraints) => MenuAnchor(
        style: kAppMenuStyle,
        builder: (context, menuController, _) => HoverTextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: '{prefix}{filename}{suffix}',
            suffixIcon: IconButton(
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppTheme.textSecondary),
              mouseCursor: SystemMouseCursors.click,
              tooltip: 'Presets',
              onPressed: () => menuController.isOpen
                  ? menuController.close()
                  : menuController.open(),
            ),
          ),
        ),
        menuChildren: [
          for (final p in presets)
            MenuItemButton(
              style: appMenuItemStyle(),
              onPressed: () {
                controller.text = p.value;
                onChanged(p.value);
              },
              child: SizedBox(
                width: constraints.maxWidth - 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.label,
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13)),
                    Text(p.value,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
