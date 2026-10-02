import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/voucher_provider.dart';
import 'voucher_form_screen.dart';
import 'voucher_pdf_preview_screen.dart';

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Vouchers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Temporary'),
            Tab(text: 'Permanent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVoucherList('Temporary'),
          _buildVoucherList('Permanent'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VoucherFormScreen(
                initialType: _tabController.index == 0 ? 'Temporary' : 'Permanent',
              ),
            ),
          );
        },
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('New Voucher', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildVoucherList(String type) {
    return Consumer<VoucherProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.vouchers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final list = type == 'Temporary' ? provider.tempVouchers : provider.permanentVouchers;

        if (list.isEmpty) {
          return const Center(
            child: Text(
              'No vouchers found.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final voucher = list[index];
            final dateStr = voucher.issueDate != null ? DateFormat('dd MMM yyyy').format(voucher.issueDate!) : 'No Date';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Show PDF
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoucherPdfPreviewScreen(voucher: voucher),
                    ),
                  );
                },
                onLongPress: () {
                  // Edit
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoucherFormScreen(voucher: voucher),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              voucher.ivNo.isNotEmpty ? 'IV No: ${voucher.ivNo}' : 'Draft Voucher',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(dateStr, style: const TextStyle(color: Colors.amber, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Issued to: ${voucher.receiptStation}', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text('Items: ${voucher.items.length}', style: const TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
