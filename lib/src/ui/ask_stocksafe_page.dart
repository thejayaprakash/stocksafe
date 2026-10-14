import 'package:drift/drift.dart' show ComparableExpr;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import 'product_detail_page.dart';
import 'pro_gate.dart';
import 'widgets/voice_assistant_dialog.dart';
import '../app_scope.dart';

class InsightAnswer {
  const InsightAnswer({
    required this.question,
    required this.summary,
    required this.details,
    this.highlightValue,
    this.relatedProducts = const [],
  });

  final String question;
  final String summary;
  final String details;
  final String? highlightValue;
  final List<Product> relatedProducts;
}

/// 'Ask StockSafe' — Local Natural Language Inventory Assistant.
/// Performs 100% offline rule-based analytics to answer key business
/// questions about stock levels, valuation, velocity, and dead stock.
class AskStockSafePage extends StatefulWidget {
  const AskStockSafePage({super.key});

  @override
  State<AskStockSafePage> createState() => _AskStockSafePageState();
}

class _AskStockSafePageState extends State<AskStockSafePage> {
  /// The live database, read through the scope rather than passed in.
  /// Uses [AppScope.read] so it is safe to call from initState; widgets that
  /// must rebuild when the connection is replaced should call AppScope.of in
  /// build instead.
  AppDatabase get _db => AppScope.read(context).db;

  final TextEditingController _queryController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  InsightAnswer? _currentAnswer;
  bool _isLoading = false;

  final List<String> _suggestedQueries = [
    'What is my total inventory purchase value?',
    'Which products are running low?',
    'Which products had the most movements this week?',
    'Are there any dead stock items?',
    'What is my estimated retail sales value?',
  ];

  @override
  void initState() {
    super.initState();
    // Default initial query
    _processQuery('What is my total inventory purchase value?');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openVoiceQuery() async {
    if (!await requirePro(context, _db)) return;
    if (!mounted) return;
    final result = await VoiceAssistantDialog.show(context);
    if (result != null && result.rawTranscript.trim().isNotEmpty) {
      _queryController.text = result.rawTranscript;
      await _processQuery(result.rawTranscript);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('Ask StockSafe AI'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Query Input Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _queryController,
              decoration: InputDecoration(
                hintText: 'Ask about stock, value, velocity...',
                prefixIcon: const Icon(Icons.psychology_outlined),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic, color: Colors.blue),
                      tooltip: 'Voice Query',
                      onPressed: _openVoiceQuery,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        final q = _queryController.text.trim();
                        if (q.isNotEmpty) _processQuery(q);
                      },
                    ),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) _processQuery(val.trim());
              },
            ),
          ),

          // Suggested Questions Chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestedQueries.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final query = _suggestedQueries[index];
                return ActionChip(
                  avatar: const Icon(Icons.bolt, size: 16, color: Colors.amber),
                  label: Text(query, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    _queryController.text = query;
                    _processQuery(query);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Answer Display Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentAnswer == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: theme.colorScheme.outlineVariant),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _currentAnswer!.question,
                                          style: theme.textTheme.titleSmall?.copyWith(color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (_currentAnswer!.highlightValue != null) ...[
                                    Text(
                                      _currentAnswer!.highlightValue!,
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    _currentAnswer!.summary,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentAnswer!.details,
                                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_currentAnswer!.relatedProducts.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                'Relevant Products (${_currentAnswer!.relatedProducts.length})',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              _currentAnswer!.relatedProducts.length,
                              (i) {
                                final p = _currentAnswer!.relatedProducts[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      'Stock: ${p.stockQty} ${p.unit} • Buy: ₹${p.buyPrice} • Sell: ₹${p.sellPrice}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductDetailPage(productId: p.id),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _processQuery(String query) async {
    setState(() => _isLoading = true);
    final q = query.toLowerCase();

    final allProducts = await _db.productDao.getAllForExport();

    InsightAnswer answer;

    if (q.contains('value') || q.contains('worth') || q.contains('cost') || q.contains('purchase')) {
      // 1. Purchase Inventory Valuation
      double totalCost = 0;
      double totalRetail = 0;
      int totalItems = 0;

      for (final p in allProducts) {
        final int qty = p.stockQty > 0 ? p.stockQty : 0;
        totalCost += qty * p.buyPrice;
        totalRetail += qty * p.sellPrice;
        totalItems += qty;
      }

      final profitPotential = totalRetail - totalCost;

      answer = InsightAnswer(
        question: query,
        highlightValue: _currencyFormat.format(totalCost),
        summary: 'Total Purchase Valuation across $totalItems units',
        details: 'Your inventory consists of ${allProducts.length} unique products. '
            'Estimated retail sales revenue is ${_currencyFormat.format(totalRetail)}, '
            'representing an estimated potential profit of ${_currencyFormat.format(profitPotential)}.',
        relatedProducts: allProducts.take(5).toList(),
      );
    } else if (q.contains('low') || q.contains('shortage') || q.contains('alert') || q.contains('restock')) {
      // 2. Low Stock Query
      final lowStockProducts = allProducts.where((p) => p.stockQty <= p.lowStockLevel).toList();

      answer = InsightAnswer(
        question: query,
        highlightValue: '${lowStockProducts.length} items',
        summary: lowStockProducts.isEmpty
            ? 'Healthy inventory! No items are currently below low stock levels.'
            : 'Immediate restock recommended for ${lowStockProducts.length} products.',
        details: lowStockProducts.isEmpty
            ? 'All products are currently stocked at or above their safety threshold.'
            : 'These products have reached or breached their minimum safety stock.',
        relatedProducts: lowStockProducts,
      );
    } else if (q.contains('dead') || q.contains('zero') || q.contains('slow') || q.contains('idle')) {
      // 3. Dead Stock / No Movement
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentMovements = await (_db.select(_db.movements)
            ..where((m) => m.createdAt.isBiggerOrEqualValue(thirtyDaysAgo)))
          .get();

      final activeProductIds = recentMovements.map((m) => m.productId).toSet();
      final deadStock = allProducts.where((p) => !activeProductIds.contains(p.id) && p.stockQty > 0).toList();

      double tiedUpCapital = 0;
      for (final p in deadStock) {
        tiedUpCapital += p.stockQty * p.buyPrice;
      }

      answer = InsightAnswer(
        question: query,
        highlightValue: '${deadStock.length} items',
        summary: 'Found ${deadStock.length} products with no movement in 30 days',
        details: 'These products hold ${_currencyFormat.format(tiedUpCapital)} in capital tied up without sales or outward movement in the past month.',
        relatedProducts: deadStock,
      );
    } else if (q.contains('movement') || q.contains('fast') || q.contains('top') || q.contains('week') || q.contains('sold')) {
      // 4. Movement velocity
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final weeklyMovements = await (_db.select(_db.movements)
            ..where((m) => m.createdAt.isBiggerOrEqualValue(sevenDaysAgo)))
          .get();

      final Map<int, int> activityCount = {};
      for (final m in weeklyMovements) {
        activityCount[m.productId] = (activityCount[m.productId] ?? 0) + m.qtyDelta.abs();
      }

      final sortedByActivity = allProducts.where((p) => activityCount.containsKey(p.id)).toList()
        ..sort((a, b) => (activityCount[b.id] ?? 0).compareTo(activityCount[a.id] ?? 0));

      answer = InsightAnswer(
        question: query,
        highlightValue: '${weeklyMovements.length} transactions',
        summary: 'Recorded ${weeklyMovements.length} movements across ${sortedByActivity.length} products this week.',
        details: sortedByActivity.isEmpty
            ? 'No movements recorded in the last 7 days.'
            : 'Top moving product: ${sortedByActivity.first.name} with ${activityCount[sortedByActivity.first.id]} units adjusted.',
        relatedProducts: sortedByActivity.take(5).toList(),
      );
    } else {
      // 5. General Overview
      final totalQty = allProducts.fold<int>(0, (sum, p) => sum + p.stockQty);
      answer = InsightAnswer(
        question: query,
        highlightValue: '${allProducts.length} Products',
        summary: 'StockSafe Inventory Summary',
        details: 'Currently managing ${allProducts.length} catalog items totaling $totalQty units in stock. '
            'Try asking: "What is my total inventory purchase value?" or "Which products are running low?".',
        relatedProducts: allProducts.take(5).toList(),
      );
    }

    if (mounted) {
      setState(() {
        _currentAnswer = answer;
        _isLoading = false;
      });
    }
  }
}
