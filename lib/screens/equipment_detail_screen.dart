import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';
import '../widgets/equipment_dialogs.dart';
import '../services/access_control.dart';

class EquipmentDetailScreen extends StatelessWidget {
  final EquipmentHead head;

  const EquipmentDetailScreen({super.key, required this.head});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (BuildContext innerContext) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(head.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1E1E1E),
              iconTheme: const IconThemeData(color: Colors.white),
              bottom: const TabBar(
                indicatorColor: Colors.orange,
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(text: 'STOCK ENTRIES'),
                  Tab(text: 'HISTORY / STATUS'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildStockEntriesTab(context),
                _buildHistoryTab(context),
              ],
            ),
            floatingActionButton: AccessControl.isAdmin(innerContext)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      // Figure out which tab is active to show the right dialog
                      final index = DefaultTabController.of(innerContext).index;
                      if (index == 0) {
                        EquipmentDialogs.showAddStockEntryDialog(innerContext, head);
                      } else {
                        EquipmentDialogs.showAddHistoryDialog(innerContext, head);
                      }
                    },
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text('ADD ENTRY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildStockEntriesTab(BuildContext context) {
    return Consumer<EquipmentProvider>(
      builder: (context, provider, child) {
        return StreamBuilder<List<EquipmentStockEntry>>(
          stream: provider.getStockEntries(head.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.orange));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }

            final entries = snapshot.data ?? [];

            if (entries.isEmpty) {
              return const Center(child: Text('No stock entries found.', style: TextStyle(color: Colors.white54)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildStockEntryCard(context, entry);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStockEntryCard(BuildContext context, EquipmentStockEntry entry) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${formatter.format(entry.dateTakenIntoCharge)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Qty: ${entry.quantity}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                    if (AccessControl.isAdmin(context))
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                        color: const Color(0xFF2C2C2C),
                        onSelected: (value) {
                          if (value == 'edit') {
                            EquipmentDialogs.showEditStockEntryDialog(context, entry);
                          } else if (value == 'delete') {
                            _confirmDeleteStockEntry(context, entry);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entry.equipmentId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('ID: ${entry.equipmentId}', style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            if (entry.brand.isNotEmpty)
              Text('Brand/Make: ${entry.brand}', style: const TextStyle(color: Colors.white70)),
            if (entry.serialNumbers.isNotEmpty)
              Text('Serial(s): ${entry.serialNumbers}', style: const TextStyle(color: Colors.white70)),
            if (entry.assignedTo.isNotEmpty)
              Text('Assigned To: ${entry.assignedTo}', style: const TextStyle(color: Colors.blueAccent)),
            if (entry.lockerNumber != null && entry.lockerNumber!.isNotEmpty)
              Text('Locker No: ${entry.lockerNumber}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    return Consumer<EquipmentProvider>(
      builder: (context, provider, child) {
        return StreamBuilder<List<EquipmentHistory>>(
          stream: provider.getHistoryEntries(head.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.orange));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            }

            final entries = snapshot.data ?? [];

            if (entries.isEmpty) {
              return const Center(child: Text('No history logs found.', style: TextStyle(color: Colors.white54)));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final log = entries[index];
                return _buildHistoryCard(context, log);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, EquipmentHistory log) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    final isUnserviceable = log.status == 'UNSERVICEABLE';
    final isStatusChange = log.type == 'STATUS_CHANGE';

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isStatusChange
            ? (isUnserviceable ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5))
            : Colors.blue.withOpacity(0.5),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8)
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isStatusChange
                    ? (isUnserviceable ? 'UNSERVICEABLE' : 'SERVICEABLE')
                    : 'TEMP ISSUE',
                  style: TextStyle(
                    color: isStatusChange
                      ? (isUnserviceable ? Colors.redAccent : Colors.greenAccent)
                      : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      formatter.format(log.fromDate),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (AccessControl.isAdmin(context))
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                        color: const Color(0xFF2C2C2C),
                        onSelected: (value) {
                          if (value == 'edit') {
                            EquipmentDialogs.showEditHistoryDialog(context, log);
                          } else if (value == 'delete') {
                            _confirmDeleteHistory(context, log);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (log.quantityAffected > 0)
              Text('Quantity Affected: ${log.quantityAffected}', style: const TextStyle(color: Colors.white)),
            if (log.voucherNumber != null && log.voucherNumber!.isNotEmpty)
              Text('Voucher: ${log.voucherNumber}', style: const TextStyle(color: Colors.white)),
            if (log.toDate != null)
              Text('Expected Return: ${formatter.format(log.toDate!)}', style: const TextStyle(color: Colors.orangeAccent)),
            if (log.remarks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('Remarks: ${log.remarks}', style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteStockEntry(BuildContext context, EquipmentStockEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Stock Entry', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this stock entry?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<EquipmentProvider>(context, listen: false).deleteStockEntry(entry);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHistory(BuildContext context, EquipmentHistory log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete History Log', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this history log?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<EquipmentProvider>(context, listen: false).deleteHistoryEntry(log);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
