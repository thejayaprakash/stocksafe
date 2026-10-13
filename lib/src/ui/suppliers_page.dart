import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database.dart';
import '../services/app_localization.dart';

/// Supplier & Vendor Contacts Directory Page.
/// Retailers can record vendor details, view mapped products,
/// and tap "Call Supplier" or message on WhatsApp instantly.
class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key, required this.db});

  final AppDatabase db;

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.tr('suppliers')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by vendor name, phone, GSTIN...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
              onChanged: (val) => setState(() => _query = val.trim()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Supplier>>(
        stream: widget.db.supplierDao.watchAll(query: _query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final suppliers = snapshot.data ?? [];

          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.contact_phone_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _query.isEmpty ? 'No suppliers registered yet' : 'No suppliers match "$_query"',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _query.isEmpty
                          ? 'Add your distributors, wholesalers and manufacturers here so you can tap to call them whenever stock is low.'
                          : 'Try searching with another name or phone number.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_query.isEmpty) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add First Supplier'),
                      onPressed: () => _showAddEditDialog(context),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final s = suppliers[index];
              return _SupplierCard(
                db: widget.db,
                supplier: s,
                onEdit: () => _showAddEditDialog(context, existing: s),
                onDelete: () => _confirmDelete(context, s),
                onTap: () => _showSupplierDetailsSheet(context, s),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Supplier'),
        onPressed: () => _showAddEditDialog(context),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {Supplier? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final phoneController = TextEditingController(text: existing?.phone ?? '');
    final gstinController = TextEditingController(text: existing?.gstin ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              existing == null ? Icons.person_add : Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(existing == null ? 'Add Supplier / Vendor' : 'Edit Supplier'),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Supplier / Business Name *',
                    hintText: 'e.g. Ramesh Wholesalers',
                    prefixIcon: Icon(Icons.store_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Supplier name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (for Calling) *',
                    hintText: 'e.g. 9876543210',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: gstinController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN (Optional)',
                    hintText: 'e.g. 33AAAAA0000A1Z5',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Delivery Days (Optional)',
                    hintText: 'e.g. Delivers every Monday, minimum order Rs 2000',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final now = DateTime.now();
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final gstin = gstinController.text.trim().isEmpty ? null : gstinController.text.trim();
              final notes = notesController.text.trim().isEmpty ? null : notesController.text.trim();

              if (existing != null) {
                await widget.db.supplierDao.updateSupplier(
                  existing.id,
                  SuppliersCompanion(
                    name: Value(name),
                    phone: Value(phone),
                    gstin: Value(gstin),
                    notes: Value(notes),
                  ),
                );
              } else {
                await widget.db.supplierDao.insertSupplier(
                  SuppliersCompanion.insert(
                    name: name,
                    phone: phone,
                    gstin: Value(gstin),
                    notes: Value(notes),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
              }

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(existing == null ? '✅ Added supplier "$name"' : '✅ Updated supplier "$name"'),
                  ),
                );
              }
            },
            child: Text(existing == null ? 'Save Supplier' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Supplier s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Supplier?'),
        content: Text(
          'Remove "${s.name}" from active suppliers?\n\n'
          'Products mapped to this supplier will have their supplier link unassigned. You can restore this vendor if needed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await widget.db.supplierDao.softDelete(s.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${s.name}"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => widget.db.supplierDao.restore(s.id),
            ),
          ),
        );
      }
    }
  }

  void _showSupplierDetailsSheet(BuildContext context, Supplier s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.teal.withValues(alpha: 0.2),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(s.phone, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    tooltip: 'Call Supplier',
                    onPressed: () => _callSupplier(s.phone),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (s.gstin != null && s.gstin!.isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long, color: Colors.blueGrey),
                  title: const Text('GSTIN'),
                  subtitle: Text(s.gstin!, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
              if (s.notes != null && s.notes!.isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes, color: Colors.blueGrey),
                  title: const Text('Notes / Delivery Terms'),
                  subtitle: Text(s.notes!),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Products Supplied by this Vendor:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              FutureBuilder<List<Product>>(
                future: widget.db.supplierDao.getProductsForSupplier(s.id),
                builder: (context, prodSnap) {
                  final prods = prodSnap.data ?? [];
                  if (prods.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No products currently assigned to this supplier.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: prods.length > 5 ? 5 : prods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, idx) {
                      final p = prods[idx];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.inventory_2_outlined, size: 20),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: Text(
                          '${p.stockQty} ${p.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: p.stockQty <= p.lowStockLevel ? Colors.red : Colors.green,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.message, color: Colors.teal),
                      label: const Text('WhatsApp'),
                      onPressed: () => _messageWhatsApp(s.phone, s.name),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Supplier'),
                      onPressed: () => _callSupplier(s.phone),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _callSupplier(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> _messageWhatsApp(String phone, String supplierName) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final text = Uri.encodeComponent('Hello $supplierName, contacting you regarding stock order.');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({
    required this.db,
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final AppDatabase db;
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card.outlined(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      supplier.name.isNotEmpty ? supplier.name[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(supplier.phone, style: theme.textTheme.bodySmall),
                            if (supplier.gstin != null && supplier.gstin!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'GST',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Direct Tap-to-Call Button
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.15),
                      foregroundColor: Colors.green.shade900,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.phone, size: 16, color: Colors.green),
                    label: const Text('Call', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final clean = supplier.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                      launchUrl(Uri.parse('tel:$clean'));
                    },
                  ),
                ],
              ),
              if (supplier.notes != null && supplier.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  supplier.notes!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                ),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<int>(
                    stream: db.supplierDao.watchProductCountForSupplier(supplier.id),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return Text(
                        '$count ${count == 1 ? "product mapped" : "products mapped"}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Supplier',
                        visualDensity: VisualDensity.compact,
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
