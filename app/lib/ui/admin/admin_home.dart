import 'package:flutter/material.dart';

import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'all_orders_page.dart';
import 'drivers_page.dart';
import 'import_page.dart';
import 'invoice_settings_page.dart';
import 'parties_page.dart';
import 'products_page.dart';
import 'users_page.dart';
import 'vehicles_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final tiles = <(IconData, String, String, Widget Function())>[
      (Icons.table_chart_outlined, t.allOrders, t.allOrdersHelp, () => const AllOrdersPage()),
      (Icons.people_outline, t.users, t.usersHelp, () => const UsersPage()),
      (Icons.storefront_outlined, t.parties, t.partiesHelp, () => const PartiesPage()),
      (Icons.inventory_2_outlined, t.products, t.productsHelp, () => const ProductsPage()),
      (Icons.local_shipping_outlined, t.vehicles, t.vehiclesHelp, () => const VehiclesPage()),
      (Icons.badge_outlined, t.drivers, t.driversHelp, () => const DriversPage()),
      (Icons.receipt_long_outlined, t.invoiceSettings, t.invoiceSettingsHelp, () => const InvoiceSettingsPage()),
      (Icons.upload_file_outlined, t.importExcel, t.importHelp, () => const ImportPage()),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(t.admin)),
      body: PageWidth(
        maxWidth: 900,
        child: GridView.extent(
          padding: const EdgeInsets.all(12),
          maxCrossAxisExtent: 420,
          childAspectRatio: 3.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final tile in tiles)
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => tile.$4())),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(tile.$1, size: 36, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tile.$2, style: Theme.of(context).textTheme.titleMedium),
                          Text(tile.$3, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
