import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fuel_provider.dart';
import '../widgets/fuel_dialogs.dart';
import 'fuel_detail_screen.dart';
import '../services/access_control.dart';

class FuelScreen extends StatelessWidget {
  const FuelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('FUEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
          actions: [
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFFFB300), // Yellow indicator
            labelColor: Color(0xFFFFB300),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'FUEL'),
              Tab(text: 'OILS'),
            ],
          ),
        ),
        body: Consumer<FuelProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.ledgers.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)));
            }
            if (provider.error != null) {
              return Center(child: Text('Error: ${provider.error}', style: const TextStyle(color: Colors.red)));
            }

            return TabBarView(
              children: [
                _buildLedgerList(context, provider.fuelLedgers),
                _buildLedgerList(context, provider.oilLedgers),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => FuelDialogs.showAddLedgerDialog(context),
              child: const Text(
                '+ ADD LEDGER HEAD',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerList(BuildContext context, List ledgers) {
    if (ledgers.isEmpty) {
      return const Center(child: Text('No ledgers found.', style: TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ledgers.length,
      itemBuilder: (context, index) {
        final ledger = ledgers[index];
        return Card(
          color: const Color(0xFF2C2C2C),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_gas_station, color: Color(0xFFFFB300)),
            ),
            title: Text(ledger.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border.all(color: const Color(0xFFFFB300)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${ledger.currentBalance.toStringAsFixed(3)} L',
                    style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (AccessControl.isAdmin(context))
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    color: const Color(0xFF2C2C2C),
                    onSelected: (value) {
                      if (value == 'edit') {
                        FuelDialogs.showEditLedgerDialog(context, ledger);
                      } else if (value == 'delete') {
                        FuelDialogs.showDeleteConfirmDialog(context, ledger);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FuelDetailScreen(ledger: ledger)),
              );
            },
          ),
        );
      },
    );
  }
}
