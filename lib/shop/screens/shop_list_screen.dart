import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../scan/providers/image_acquisition_provider.dart';
import '../../scan/widgets/scan_image_preview.dart';
import '../models/shop_models.dart';
import '../state/shop_controller.dart';
import '../utils/currency_formatter.dart';

/// Grocery vs. fitness/wellness lists and basket — a status
/// (planned/in basket/purchased) on each line, editable price/quantity/
/// currency/store, and spending totals kept strictly separate per list
/// type and per currency (never a fake FX conversion). See
/// `ShopController` for the underlying save/update contract.
class ShopListScreen extends ConsumerStatefulWidget {
  const ShopListScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ShopListScreen> createState() => _ShopListScreenState();
}

class _ShopListScreenState extends ConsumerState<ShopListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shopControllerProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Grocery & Wellness Lists',
              subtitle: 'Your basket, spending, and shopping lists',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.blue,
              tabs: const [
                Tab(text: 'Grocery'),
                Tab(text: 'Fitness & Wellness'),
              ],
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (_, _) => Center(
                  child: Text(
                    'Could not load your lists.',
                    style: AppTextStyles.subtitle,
                  ),
                ),
                data: (state) => TabBarView(
                  controller: _tabController,
                  children: [
                    _ListView(state: state, listType: ShopListType.grocery),
                    _ListView(state: state, listType: ShopListType.fitness),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  const _ListView({required this.state, required this.listType});
  final ShopState state;
  final ShopListType listType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = state.itemsFor(listType);
    final weekly = state.spendingInLastDays(listType, 7);
    final monthly = state.spendingInLastDays(listType, 30);

    final planned = items
        .where((i) => i.status == ShopItemStatus.planned)
        .toList();
    final inBasket = items
        .where((i) => i.status == ShopItemStatus.inBasket)
        .toList();
    final purchased =
        items.where((i) => i.status == ShopItemStatus.purchased).toList()..sort(
          (a, b) => (b.purchaseDate ?? b.addedAt).compareTo(
            a.purchaseDate ?? a.addedAt,
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        GlowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Spending',
                style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 8),
              _totalsRow('Last 7 days', weekly),
              const SizedBox(height: 4),
              _totalsRow('Last 30 days', monthly),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (items.isEmpty)
          GlowCard(
            child: Text(
              'Nothing here yet — scan or add a product to get started.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          ),
        if (inBasket.isNotEmpty) ..._section('In Basket', inBasket, ref),
        if (planned.isNotEmpty) ..._section('Planned', planned, ref),
        if (purchased.isNotEmpty) ..._section('Purchased', purchased, ref),
      ],
    );
  }

  Widget _totalsRow(String label, Map<String, double> totals) {
    final text = totals.isEmpty
        ? 'No purchases yet'
        : totals.entries
              .map((e) => formatCurrency(e.value, e.key))
              .join('  ·  ');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 13)),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 13,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _section(
    String title,
    List<ShopListItem> sectionItems,
    WidgetRef ref,
  ) {
    return [
      Text(
        title,
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 10),
      for (final item in sectionItems) ...[
        _ListItemCard(item: item),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 10),
    ];
  }
}

class _ListItemCard extends ConsumerWidget {
  const _ListItemCard({required this.item});
  final ShopListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(shopControllerProvider.notifier);
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: AppTextStyles.subtitle.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    if (item.brand != null)
                      Text(
                        item.brand!,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Remove ${item.productName}',
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => controller.removeListItem(item.id),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QuantityStepper(
                quantity: item.quantity,
                onChanged: (q) =>
                    controller.updateListItem(item.id, quantity: q),
              ),
              const Spacer(),
              if (item.lineTotal != null && item.currencyCode != null)
                Text(
                  formatCurrency(item.lineTotal!, item.currencyCode!),
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  'No price yet',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
            ],
          ),
          if (item.storeName != null) ...[
            const SizedBox(height: 4),
            Text(
              item.storeName!,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionChip(
                label: 'Price & Store',
                onTap: () => _showPriceDialog(context, ref, item),
              ),
              if (item.status != ShopItemStatus.inBasket &&
                  item.status != ShopItemStatus.purchased)
                _ActionChip(
                  label: 'Move to Basket',
                  onTap: () => controller.updateListItem(
                    item.id,
                    status: ShopItemStatus.inBasket,
                  ),
                ),
              if (item.status != ShopItemStatus.purchased)
                _ActionChip(
                  label: 'Mark Purchased',
                  onTap: () => controller.markPurchased(
                    item.id,
                    purchaseDate: DateTime.now(),
                    storeName: item.storeName,
                  ),
                ),
              if (item.status == ShopItemStatus.purchased)
                _ActionChip(
                  label: 'Attach Receipt',
                  onTap: () => _attachReceipt(context, ref, item),
                ),
            ],
          ),
          if (item.receiptImagePath != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: ScanImagePreview(
                  path: item.receiptImagePath!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _attachReceipt(
    BuildContext context,
    WidgetRef ref,
    ShopListItem item,
  ) async {
    final acquisition = ImagePickerAcquisitionProvider();
    final path = await acquisition.pickFromGallery();
    if (path == null) return;
    final controller = ref.read(shopControllerProvider.notifier);
    final stored = await controller.saveReceiptImage(path);
    if (stored == null) return;
    await controller.updateListItem(item.id, receiptImagePath: stored);
  }

  Future<void> _showPriceDialog(
    BuildContext context,
    WidgetRef ref,
    ShopListItem item,
  ) async {
    final priceController = TextEditingController(
      text: item.unitPrice?.toString() ?? '',
    );
    final storeController = TextEditingController(text: item.storeName ?? '');
    String currency = item.currencyCode ?? kSupportedCurrencyCodes.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1B2E),
          title: Text(
            'Price & store',
            style: AppTextStyles.cardTitle.copyWith(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: currency,
                dropdownColor: const Color(0xFF1A1B2E),
                isExpanded: true,
                items: [
                  for (final code in kSupportedCurrencyCodes)
                    DropdownMenuItem(
                      value: code,
                      child: Text(
                        code,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                onChanged: (v) =>
                    setDialogState(() => currency = v ?? currency),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Shelf price per unit',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: storeController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Store name (optional)',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final price = double.tryParse(priceController.text.trim());
                ref
                    .read(shopControllerProvider.notifier)
                    .updateListItem(
                      item.id,
                      unitPrice: price,
                      clearUnitPrice: price == null,
                      currencyCode: currency,
                      storeName: storeController.text.trim().isEmpty
                          ? null
                          : storeController.text.trim(),
                      clearStoreName: storeController.text.trim().isEmpty,
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});
  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Decrease quantity',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
        ),
        Text(
          '$quantity',
          style: AppTextStyles.cardTitle.copyWith(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        Semantics(
          button: true,
          label: 'Increase quantity',
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.add_circle_outline,
              size: 20,
              color: AppColors.textSecondary,
            ),
            onPressed: () => onChanged(quantity + 1),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              fontSize: 11,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
