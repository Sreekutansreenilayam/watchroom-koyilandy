import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/contact_model.dart';
import '../providers/contact_provider.dart';
import 'package:uuid/uuid.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _altPhoneController = TextEditingController();
  final _designationController = TextEditingController();

  String _searchQuery = '';
  String? _expandedCategory;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _altPhoneController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  void _showFormDialog(BuildContext context, [ContactModel? existingContact]) {
    final provider = context.read<ContactProvider>();
    final existingCategories = provider.contacts.map((c) => c.category).toSet().toList();
    final defaultCategories = ['Police', 'Hospital', 'Officials', 'Fire Stations'];
    for (var cat in defaultCategories) {
      if (!existingCategories.contains(cat)) {
        existingCategories.add(cat);
      }
    }
    existingCategories.sort();
    final categories = [...existingCategories, '+ Add New'];

    if (existingContact != null) {
      _nameController.text = existingContact.name;
      _categoryController.text = existingContact.category;
      _phoneController.text = existingContact.phoneNumber;
      _altPhoneController.text = existingContact.alternativeNumber ?? '';
      _designationController.text = existingContact.designation ?? '';
    } else {
      _nameController.clear();
      _categoryController.clear(); // Set to empty by default

      _phoneController.clear();
      _altPhoneController.clear();
      _designationController.clear();
    }

    if (_categoryController.text.isNotEmpty && !categories.contains(_categoryController.text)) {
      categories.insert(0, _categoryController.text);
    }


    bool isAddingNewCategory = false;
    final newCategoryController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existingContact == null ? 'Add New Contact' : 'Edit Contact',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Name / Organization', labelStyle: TextStyle(color: Colors.white70)),
                        validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: isAddingNewCategory ? '+ Add New' : (_categoryController.text.isEmpty ? null : _categoryController.text),
                        dropdownColor: const Color(0xFF2C2C2C),
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Category', labelStyle: TextStyle(color: Colors.white70)),
                        validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                        items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              if (val == '+ Add New') {
                                isAddingNewCategory = true;
                              } else {
                                isAddingNewCategory = false;
                                _categoryController.text = val;
                              }
                            });
                          }
                        },
                      ),
                      if (isAddingNewCategory) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: newCategoryController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'New Category Name', labelStyle: TextStyle(color: Colors.white70)),
                          validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                        ),
                      ],

                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: Colors.white70)),
                        validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _altPhoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Alternative Number (Optional)', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            String finalCategory = isAddingNewCategory ? newCategoryController.text.trim() : _categoryController.text.trim();

                            if (existingContact == null) {
                              provider.addContact(ContactModel(
                                id: const Uuid().v4(),
                                name: _nameController.text.trim(),
                                category: finalCategory,
                                phoneNumber: _phoneController.text.trim(),
                                alternativeNumber: _altPhoneController.text.trim().isEmpty ? null : _altPhoneController.text.trim(),
                                designation: null,
                              ));
                            } else {
                              provider.updateContact(ContactModel(
                                id: existingContact.id,
                                name: _nameController.text.trim(),
                                category: finalCategory,
                                phoneNumber: _phoneController.text.trim(),
                                alternativeNumber: _altPhoneController.text.trim().isEmpty ? null : _altPhoneController.text.trim(),
                                designation: null,
                              ));
                            }
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: Text(existingContact == null ? 'Save Contact' : 'Update Contact', style: const TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied: $text'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Phone Directory', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFF1E2A38),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: Consumer<ContactProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final filteredContacts = provider.contacts.where((c) {
                      return c.name.toLowerCase().contains(_searchQuery) ||
                             c.phoneNumber.contains(_searchQuery) ||
                             c.category.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filteredContacts.isEmpty) {
                      return const Center(child: Text('No contacts found', style: TextStyle(color: Colors.white54)));
                    }

                    // Group by category
                    final Map<String, List<ContactModel>> groupedContacts = {};
                    for (var c in filteredContacts) {
                      if (!groupedContacts.containsKey(c.category)) {
                        groupedContacts[c.category] = [];
                      }
                      groupedContacts[c.category]!.add(c);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 88),
                      itemCount: groupedContacts.keys.length,
                      itemBuilder: (context, index) {
                        String category = groupedContacts.keys.elementAt(index);
                        List<ContactModel> categoryContacts = groupedContacts[category]!;

                        bool isExpanded = _expandedCategory == category || _searchQuery.isNotEmpty;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (_expandedCategory == category) {
                                    _expandedCategory = null;
                                  } else {
                                    _expandedCategory = category;
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        category.toUpperCase(),
                                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                      ),
                                    ),
                                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blueAccent),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedCrossFade(
                              firstChild: Container(height: 0),
                              secondChild: ReorderableListView(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                onReorder: (oldIndex, newIndex) {
                                  provider.reorderWithinCategory(category, oldIndex, newIndex);
                                },
                                children: categoryContacts.map((contact) {
                                  return _buildContactCard(contact, key: ValueKey(contact.id));
                                }).toList(),
                              ),
                              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 200),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(context),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContactCard(ContactModel contact, {Key? key}) {
    return Card(
      key: key,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                  child: Text(contact.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 44), // Align with text (16*2 + 12 = 44)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (contact.designation != null && contact.designation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(contact.designation!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Tooltip(
                              message: contact.phoneNumber,
                              triggerMode: TooltipTriggerMode.tap,
                              child: Text(contact.phoneNumber, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                      if (contact.alternativeNumber != null && contact.alternativeNumber!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Tooltip(
                                  message: contact.alternativeNumber!,
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Text(contact.alternativeNumber!, style: const TextStyle(color: Colors.white70), overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.call, color: Colors.green, size: 20),
                  onPressed: () => _handleContactAction(context, contact, 'call'),
                  tooltip: 'Call',
                ),
                const SizedBox(width: 16),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                  color: const Color(0xFF2C2C2C),
                  onSelected: (value) {
                    if (value == 'copy') {
                      _handleContactAction(context, contact, 'copy');
                    } else if (value == 'edit') {
                      _showFormDialog(context, contact);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(contact);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'copy', child: Text('Copy Number', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleContactAction(BuildContext context, ContactModel contact, String actionType) {
    if (contact.alternativeNumber == null || contact.alternativeNumber!.isEmpty) {
      _executeAction(contact.phoneNumber, actionType);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Select number to ${actionType == 'call' ? 'Call' : 'Copy'}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: Icon(actionType == 'call' ? Icons.call : Icons.copy, color: Colors.blueAccent),
              title: Text(contact.phoneNumber, style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Primary', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _executeAction(contact.phoneNumber, actionType);
              },
            ),
            ListTile(
              leading: Icon(actionType == 'call' ? Icons.call : Icons.copy, color: Colors.blueAccent),
              title: Text(contact.alternativeNumber!, style: const TextStyle(color: Colors.white)),
              subtitle: const Text('Alternative', style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _executeAction(contact.alternativeNumber!, actionType);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _executeAction(String number, String actionType) {
    if (actionType == 'call') {
      _makePhoneCall(number);
    } else if (actionType == 'copy') {
      _copyToClipboard(number);
    }
  }

  void _showDeleteConfirmDialog(ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Contact?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${contact.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () {
              context.read<ContactProvider>().deleteContact(contact.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
