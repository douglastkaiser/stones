import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, this.service});
  final FeedbackService? service;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _description = TextEditingController();
  late final _service = widget.service ?? FeedbackService();
  late final _appDetails = FeedbackReport.currentAppDetails();
  FeedbackKind _kind = FeedbackKind.problem;
  bool _includeAppDetails = true;
  bool _opening = false;
  String? _status;

  FeedbackReport get _report => FeedbackReport(
      kind: _kind,
      summary: _summary.text,
      description: _description.text,
      appDetails: _appDetails,
      includeAppDetails: _includeAppDetails);

  @override
  void dispose() {
    _summary.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _openEmail() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = true);
    final opened = await _service.open(_report);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _status = opened
          ? 'Finish sending in your email app. If no draft appeared, copy the report below.'
          : 'Could not open an email draft. Copy the report and email it to ${FeedbackReport.recipient}.';
    });
  }

  Future<void> _copy() async {
    if (!_form.currentState!.validate()) return;
    try {
      await Clipboard.setData(ClipboardData(text: _report.copyText));
      if (!mounted) return;
      setState(() => _status =
          'Report copied. Paste it into an email to ${FeedbackReport.recipient}.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _status =
          'Could not copy. Expand Preview report to select and copy the text.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Send feedback')),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Help improve Stones',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      const Text(
                          'Report a problem or suggest an improvement. Your email app opens a draft for you to review and send.'),
                      const SizedBox(height: 8),
                      const SelectableText(FeedbackReport.recipient),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<FeedbackKind>(
                        initialValue: _kind,
                        decoration:
                            const InputDecoration(labelText: 'Feedback type'),
                        items: [
                          for (final kind in FeedbackKind.values)
                            DropdownMenuItem(
                                value: kind, child: Text(kind.label)),
                        ],
                        onChanged: (kind) {
                          if (kind != null) setState(() => _kind = kind);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _summary,
                        decoration:
                            const InputDecoration(labelText: 'Short summary'),
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Add a short summary.'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _description,
                        decoration: const InputDecoration(
                            labelText: 'Details',
                            alignLabelWithHint: true,
                            helperText:
                                'What did you try? What happened, and what did you expect?',
                            helperMaxLines: 3),
                        minLines: 5,
                        maxLines: 12,
                        maxLength: 2000,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) => setState(() {}),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Add a few details so we can help.'
                                : null,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                          'Include only details you want to share. Avoid passwords, invitation codes and private game content. Your email address will be visible when you send.'),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Include app details'),
                        subtitle: Text(_appDetails),
                        value: _includeAppDetails,
                        onChanged: (value) =>
                            setState(() => _includeAppDetails = value ?? false),
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Preview report'),
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: SelectableText(_report.copyText)),
                          const SizedBox(height: 16),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        FilledButton.icon(
                            onPressed: _opening ? null : _openEmail,
                            icon: const Icon(Icons.mail_outline),
                            label: Text(
                                _opening ? 'Opening…' : 'Open email draft')),
                        OutlinedButton.icon(
                            onPressed: _copy,
                            icon: const Icon(Icons.copy_outlined),
                            label: const Text('Copy report')),
                      ]),
                      if (_status != null) ...[
                        const SizedBox(height: 16),
                        Semantics(liveRegion: true, child: Text(_status!)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
