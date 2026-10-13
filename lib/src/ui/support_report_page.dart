import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_scope.dart';
import '../data/dao/setting_dao.dart';
import '../services/support_bundle.dart';

/// Lets a shopkeeper report a problem with enough context to act on.
///
/// **The app sends nothing.** The bundle goes out through the share sheet,
/// from the shopkeeper's own WhatsApp or mail account, after they have seen
/// exactly what it contains. That is the same mechanism as the Call Supplier
/// button — an Android intent to another app, not a network call — and it is
/// what keeps the manifest free of the INTERNET permission and the privacy
/// policy true without edits.
///
/// The preview step is not optional. It is what makes "we never take your
/// data" something a shopkeeper can check rather than something they have to
/// believe.
class SupportReportPage extends StatefulWidget {
  const SupportReportPage({super.key});

  @override
  State<SupportReportPage> createState() => _SupportReportPageState();
}

class _SupportReportPageState extends State<SupportReportPage> {
  final _description = TextEditingController();
  SupportArea _area = SupportArea.other;
  SupportWhen _when = SupportWhen.justNow;
  SupportBundle? _bundle;
  bool _building = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what went wrong.')),
      );
      return;
    }

    setState(() => _building = true);
    final db = AppScope.read(context).db;

    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {
      // Not fatal: the version is useful, not essential.
    }

    final bundle = await SupportBundle.build(
      db: db,
      area: _area,
      when: _when,
      description: _description.text,
      packageInfo: info,
    );

    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _building = false;
    });
  }

  /// Remembered so "Help & Support" can show the last reference, and so a
  /// follow-up message can be tied to a report.
  Future<void> _remember(SupportBundle bundle) async {
    final db = AppScope.read(context).db;
    await db.settingDao.set(SettingDao.lastSupportRefKey, bundle.reference);
    await db.settingDao
        .set(SettingDao.lastSupportAtKey, DateTime.now().toIso8601String());
  }

  Future<void> _share(SupportBundle bundle) async {
    await _remember(bundle);
    if (!mounted) return;

    // Attached as a file rather than pasted inline: a 60KB message body is
    // unusable in WhatsApp, and a .txt attachment opens fine on both ends.
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${bundle.reference}.txt');
      await file.writeAsString(bundle.json);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: 'StockSafe problem report ${bundle.reference}',
          text: 'StockSafe problem report ${bundle.reference}\n\n'
              '${_description.text.trim()}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the share sheet: $e')),
      );
      return;
    }

    if (mounted) _showSent(bundle);
  }

  Future<void> _copy(SupportBundle bundle) async {
    await _remember(bundle);
    await Clipboard.setData(ClipboardData(text: bundle.json));
    if (mounted) _showSent(bundle);
  }

  void _showSent(SupportBundle bundle) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
        title: const Text('Keep this reference'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              bundle.reference,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quote it if you follow up. You can find it again under '
              'Help & Support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(
        title: Text(bundle == null ? 'Report a problem' : 'Check before sending'),
      ),
      body: bundle == null ? _form() : _preview(bundle),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tell us what happened and StockSafe will put together a report you '
          'can send on WhatsApp or by email.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 20),

        const _Label('What went wrong?'),
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. The scanner beeps but the product does not open',
          ),
        ),
        const SizedBox(height: 20),

        const _Label('Which part of the app?'),
        Wrap(
          spacing: 8,
          children: [
            for (final a in SupportArea.values)
              ChoiceChip(
                label: Text(a.label),
                selected: _area == a,
                onSelected: (_) => setState(() => _area = a),
              ),
          ],
        ),
        const SizedBox(height: 20),

        const _Label('When did it happen?'),
        Wrap(
          spacing: 8,
          children: [
            for (final w in SupportWhen.values)
              ChoiceChip(
                label: Text(w.label),
                selected: _when == w,
                onSelected: (_) => setState(() => _when = w),
              ),
          ],
        ),
        const SizedBox(height: 28),

        FilledButton.icon(
          onPressed: _building ? null : _prepare,
          icon: _building
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward),
          label: const Text('Next: see what will be sent'),
        ),
      ],
    );
  }

  Widget _preview(SupportBundle bundle) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.green.withValues(alpha: 0.10),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'This is everything that will be sent',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'No product names, barcodes, prices, stock levels or supplier '
                'details are included — only counts. Nothing is sent until you '
                'choose an app below.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                bundle.json,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _share(bundle),
                    icon: const Icon(Icons.send),
                    label: const Text('Send on WhatsApp or email'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copy(bundle),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _bundle = null),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
}
