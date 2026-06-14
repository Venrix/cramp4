import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/encode_job.dart';
import '../providers/encoding_provider.dart';
import '../theme/app_theme.dart';

class ProcessQueueCard extends StatefulWidget {
  const ProcessQueueCard({super.key});

  @override
  State<ProcessQueueCard> createState() => _ProcessQueueCardState();
}

class _ProcessQueueCardState extends State<ProcessQueueCard> {
  final ScrollController _scrollController = ScrollController();

  // Live-tail only while the user is parked at the bottom; scrolling up to
  // read or select text pauses auto-scroll until they return to the bottom.
  bool _pinnedToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updatePinned);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updatePinned() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // maxScrollExtent throws until the viewport has reported its dimensions.
    if (!position.hasContentDimensions) return;
    _pinnedToBottom = position.pixels >= position.maxScrollExtent - 24;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      // maxScrollExtent is null until the viewport reports dimensions.
      if (!position.hasContentDimensions) return;
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final encoding = context.watch<EncodingProvider>();
    final job = encoding.currentJob;

    if (job != null && _pinnedToBottom) {
      _scrollToBottom();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_outlined, size: 26, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Process Queue',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (job == null)
              const Expanded(
                child: Center(
                  child: Text(
                    'No active job',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(child: _JobView(job: job, scrollController: _scrollController)),
          ],
        ),
      ),
    );
  }
}

class _JobView extends StatelessWidget {
  final EncodeJob job;
  final ScrollController scrollController;

  const _JobView({required this.job, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                job.outputFilename,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${(job.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'STATUS: ',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            Text(
              job.statusDisplay,
              style: TextStyle(
                color: _statusColor(job.status),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (job.remainingDisplay != null) ...[
              const SizedBox(width: 16),
              Text(
                'REMAINING: ',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Text(
                job.remainingDisplay!,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: job.progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectionArea(
              child: ListView.builder(
                controller: scrollController,
                itemCount: job.logLines.length,
                itemBuilder: (_, i) => Text(
                  job.logLines[i],
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'Consolas',
                  ),
                ),
              ),
            ),
          ),
        ),
        if (job.status == JobStatus.done) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {
                if (Platform.isWindows) {
                  Process.run('explorer', ['/select,', job.outputPath.replaceAll('/', '\\')]);
                } else {
                  final dir = job.outputPath.substring(0, job.outputPath.lastIndexOf('/'));
                  Process.run('xdg-open', [dir]);
                }
              },
              icon: const Icon(Icons.folder_open_outlined, size: 16),
              label: Text(Platform.isWindows ? 'Show in Explorer' : 'Open Folder'),
            ),
          ),
        ],
      ],
    );
  }

  Color _statusColor(JobStatus status) => switch (status) {
        JobStatus.pass1 || JobStatus.pass2 || JobStatus.encoding => AppTheme.statusEncoding,
        JobStatus.done => AppTheme.statusDone,
        JobStatus.failed => AppTheme.statusError,
        JobStatus.aborted => Colors.grey,
        JobStatus.idle => AppTheme.textSecondary,
      };
}
