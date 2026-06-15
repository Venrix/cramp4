import 'package:flutter/material.dart';

import '../models/encode_settings.dart';
import '../models/file_info.dart';
import '../services/ffmpeg_service.dart';
import '../theme/app_theme.dart';
import 'app_menu_style.dart';
import 'hover_text_field.dart';

/// Renders the filename a template would produce, for live previews. Uses the
/// loaded file + trim when present, otherwise stand-in sample values. [template]
/// must already have {templatedefault} resolved.
String previewOutputName({
  required String template,
  required FileInfo? fileInfo,
  required EncodeSettings settings,
  required Duration trimStart,
  required Duration trimEnd,
}) {
  final hasFile = fileInfo != null;
  final ext = settings.videoEnabled ? 'mp4' : settings.audioFormat.extension;
  final res = resolutionLabel(settings, fileInfo?.resolution);
  return const FfmpegService().renderFilenameTemplate(
    template: template,
    inputPath: hasFile ? fileInfo.path : 'my_video.mp4',
    ext: ext,
    trimStart: hasFile ? trimStart : Duration.zero,
    trimEnd: hasFile ? trimEnd : const Duration(minutes: 1, seconds: 23),
    now: DateTime.now(),
    resLabel: res.isEmpty ? '1080p' : res,
  );
}

class TemplatePreset {
  final String label;
  final String value;
  const TemplatePreset(this.label, this.value);
}

/// Shared preset suggestions. Tokens are lowercase (resolution is
/// case-insensitive). The encode tab prepends an "Inherit" entry, see
/// [kEncodeTemplatePresets].
const kFilenameTemplatePresets = <TemplatePreset>[
  TemplatePreset('Default', '{filename}_cramp4'),
  TemplatePreset('LosslessCut', '{filename}-{cut_from}-{cut_to}{seg_suffix}{ext}'),
  TemplatePreset(
      'Resolution + range', '{filename}_{res}_{cut_from}-{cut_to}'),
  TemplatePreset('Trim range', '{filename}_{cut_from}-{cut_to}'),
  TemplatePreset('With date', '{filename}_{date}'),
  TemplatePreset('With resolution', '{filename}_{res}'),
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
            hintText: '{filename}_cramp4',
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
