import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fuel_provider.dart';
import '../models/fuel_model.dart';
import '../widgets/fuel_dialogs.dart';
import '../services/fuel_pdf_service.dart';
import 'fuel_pdf_preview_screen.dart';
import '../services/access_control.dart';

class FuelDetailScreen extends StatelessWidget {
  final FuelLedger ledger;

  const FuelDetailScreen({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(ledger.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            onPressed: () async {
              final provider = Provider.of<FuelProvider>(context, listen: false);
              // Fetch all transactions for this ledger to generate PDF
              // In a real app, this might be a future call, but we can get it from the stream data if we pass it,
              // or just fetch once from firestore. Let's do a quick fetch.
              try {
                final snapshot = await provider.getTransactionsForLedger(ledger.id).first;
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FuelPdfPreviewScreen(
                        ledger: ledger,
                        transactions: snapshot,
                      ),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to generate PDF: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Consumer<FuelProvider>(
        builder: (context, provider, child) {
          return StreamBuilder<List<FuelTransaction>>(
            stream: provider.getTransactionsForLedger(ledger.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB300)));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return const Center(child: Text('No transactions found.', style: TextStyle(color: Colors.white54)));
              }

              return Column(
                children: [
                  _buildHeaderRow(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        // Transactions are sorted descending by date from stream,
                        // so Sl number logic needs to account for this if we want them sequentially numbered.
                        // For display, we can just use the index for simplicity or derive it.
                        final tx = transactions[index];
                        final slNo = index + 1;
                        return _buildTransactionRow(context, slNo, tx, ledger);
                      },
                    ),
                  ),
                ],
              );
            },
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
            onPressed: () => FuelDialogs.showAddEntryDialog(context, ledger),
            child: const Text(
              '+ ADD ENTRY',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: const Color(0xFF2C2C2C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: const [
          SizedBox(width: 30, child: Text('Sl', style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(width: 80, child: Text('Date', style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 2, child: Text('Party', style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('Type', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(flex: 1, child: Text('Bal', textAlign: TextAlign.right, style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, int slNo, FuelTransaction tx, FuelLedger ledger) {
    final dateStr = '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';
    final isReceipt = tx.type == 'RECEIPT';

    String displayParty = tx.party;
    if (displayParty.toLowerCase() != 'opening balance' &&
        !displayParty.toLowerCase().startsWith('issued to') &&
        !displayParty.toLowerCase().startsWith('received from')) {
      if (tx.type == 'ISSUE') {
        displayParty = 'Issued to $displayParty (MTU)';
      } else if (tx.type == 'RECEIPT') {
        displayParty = 'Received from $displayParty';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text('$slNo', style: const TextStyle(color: Colors.white70, fontSize: 12))),
          SizedBox(width: 80, child: Text(dateStr, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.voucherNumber, style: const TextStyle(color: Color(0xFFFFB300), fontSize: 10)),
                Text(displayParty, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: isReceipt ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isReceipt ? 'RECEIPT' : 'ISSUE',
                  style: TextStyle(color: isReceipt ? Colors.green : Colors.red, fontSize: 10),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${isReceipt ? '+' : '-'}${tx.quantity.toStringAsFixed(3)} L',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${tx.balanceAfter.toStringAsFixed(3)} L',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFFFFB300), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          if (AccessControl.isAdmin(context) || AccessControl.isSfroM(context))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
              padding: EdgeInsets.zero,
              color: const Color(0xFF2C2C2C),
              onSelected: (value) {
                if (tx.linkedLogbookEntryId != null && tx.linkedLogbookEntryId!.isNotEmpty && tx.type == 'RECEIPT') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ഈ ഫ്യുവൽ ഡ്രെയിൻ എൻട്രി ലോഗ്ബുക്കിൽ നിന്നും സ്വയമേവ വന്നതാണ്. അതിനാൽ ഫ്യുവൽ ലെഡ്ജറിൽ നിന്നും ഇത് തിരുത്താനോ ഡിലീറ്റ് ചെയ്യാനോ സാധിക്കില്ല. ഇതിനായി ദയവായി അതാത് വാഹനത്തിന്റെ ലോഗ്ബുക്കിൽ പോകുക.',
                        textAlign: TextAlign.center,
                      ),
                      backgroundColor: Colors.redAccent,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }

                if (value == 'edit') {
                  FuelDialogs.showEditTransactionDialog(context, tx, ledger);
                } else if (value == 'delete') {
                  FuelDialogs.showDeleteTransactionConfirmDialog(context, tx);
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
            )
          else
            const SizedBox(width: 24), // For alignment consistency if needed, but not strictly required.
        ],
      ),
    );
  }
}
