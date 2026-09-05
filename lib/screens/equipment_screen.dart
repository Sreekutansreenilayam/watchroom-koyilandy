import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/equipment_provider.dart';
import '../models/equipment_model.dart';
import 'equipment_detail_screen.dart';
import '../widgets/equipment_dialogs.dart';
import '../services/access_control.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final Set<String> _collapsedCategories = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Equipments', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<EquipmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.equipments.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (provider.equipments.isEmpty) {
            return const Center(
              child: Text(
                'No equipments found.\nClick + to add a new equipment category.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          // Group equipments by category, stripping parentheses for grouping
          Map<String, List<EquipmentHead>> grouped = {};
          for (var eq in provider.equipments) {
            String displayCategory = eq.category.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
            if (!grouped.containsKey(displayCategory)) {
              grouped[displayCategory] = [];
            }
            grouped[displayCategory]!.add(eq);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              String category = grouped.keys.elementAt(index);
              List<EquipmentHead> items = grouped[category]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_collapsedCategories.contains(category)) {
                          _collapsedCategories.remove(category);
                        } else {
                          _collapsedCategories.add(category);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            _collapsedCategories.contains(category)
                                ? Icons.expand_more
                                : Icons.expand_less,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_collapsedCategories.contains(category))
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final head = items[i];
                        return _buildEquipmentCard(context, head);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'reportBtn',
            onPressed: () => EquipmentDialogs.showEquipmentReportFilterDialog(context),
            backgroundColor: Colors.blueAccent,
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('GENERATE REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          if (AccessControl.isAdmin(context)) ...[
            const SizedBox(width: 16),
            FloatingActionButton.extended(
              heroTag: 'addBtn',
              onPressed: () => EquipmentDialogs.showAddEquipmentHeadDialog(context),
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('ADD EQUIPMENT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(BuildContext context, EquipmentHead head) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EquipmentDetailScreen(head: head)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      head.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge('Total: ${head.totalQty}', Colors.blueGrey),
                        _buildBadge('Serviceable: ${head.serviceableQty}', Colors.green),
                        _buildBadge('Unserviceable: ${head.unserviceableQty}', Colors.red),
                        _buildBadge('Available: ${head.serviceableQty - head.issuedQty}', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              if (AccessControl.isAdmin(context))
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54),
                  color: const Color(0xFF2C2C2C),
                  onSelected: (value) {
                    if (value == 'edit') {
                      EquipmentDialogs.showEditEquipmentHeadDialog(context, head);
                    } else if (value == 'delete') {
                      _confirmDeleteHead(context, head);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit', style: TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _confirmDeleteHead(BuildContext context, EquipmentHead head) {
    if (head.totalQty > 0 || head.unserviceableQty > 0 || head.serviceableQty > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete equipment with existing stock or history.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Equipment', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${head.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<EquipmentProvider>(context, listen: false).deleteEquipmentHead(head.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
