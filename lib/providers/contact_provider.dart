import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import 'package:uuid/uuid.dart';

class ContactProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ContactModel> _contacts = [];
  bool _isLoading = true;

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;

  ContactProvider() {
    _initContacts();
  }

  Future<void> _initContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('contacts_migrated_to_firebase') ?? false;

      if (!migrated) {
        await _migrateFromLocalToFirebase();
        await prefs.setBool('contacts_migrated_to_firebase', true);
      }

      await _fetchContactsFromFirebase();
    } catch (e) {
      debugPrint('Error initializing contacts: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _migrateFromLocalToFirebase() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getStringList('contacts_data') ?? [];
    
    if (contactsJson.isNotEmpty) {
      List<ContactModel> localContacts = contactsJson.map((jsonStr) => ContactModel.fromJson(jsonStr)).toList();
      
      // Ensure they have orderIndex and upload
      for (int i = 0; i < localContacts.length; i++) {
        ContactModel c = localContacts[i];
        ContactModel newC = ContactModel(
          id: c.id,
          name: c.name,
          category: c.category,
          phoneNumber: c.phoneNumber,
          alternativeNumber: c.alternativeNumber,
          designation: c.designation,
          orderIndex: i,
        );
        await _firestore.collection('contacts').doc(newC.id).set(newC.toMap());
      }
    } else {
      // Add default contacts to Firebase if no local data
      List<ContactModel> defaultContacts = [
        ContactModel(id: const Uuid().v4(), name: 'Police Station', category: 'Police', phoneNumber: '112', orderIndex: 0),
        ContactModel(id: const Uuid().v4(), name: 'General Hospital', category: 'Hospital', phoneNumber: '108', orderIndex: 1),
        ContactModel(id: const Uuid().v4(), name: 'District Collector', category: 'Officials', phoneNumber: '04952371400', orderIndex: 2),
      ];
      for (var c in defaultContacts) {
        await _firestore.collection('contacts').doc(c.id).set(c.toMap());
      }
    }
  }

  Future<void> _fetchContactsFromFirebase() async {
    try {
      final snapshot = await _firestore.collection('contacts').orderBy('orderIndex').get();
      _contacts = snapshot.docs.map((doc) => ContactModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Error fetching contacts from firebase: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchContacts() async {
    await _fetchContactsFromFirebase();
  }

  Future<void> addContact(ContactModel contact) async {
    List<int> categoryIndices = [];
    for (int i = 0; i < _contacts.length; i++) {
      if (_contacts[i].category == contact.category) {
        categoryIndices.add(i);
      }
    }

    int insertIndex = 0;
    if (categoryIndices.isEmpty) {
      insertIndex = _contacts.length;
    } else {
      insertIndex = categoryIndices.last + 1;
      for (int i in categoryIndices) {
        if (contact.name.toLowerCase().compareTo(_contacts[i].name.toLowerCase()) < 0) {
          insertIndex = i;
          break;
        }
      }
    }

    // Assign new order index
    ContactModel newContact = ContactModel(
      id: contact.id.isEmpty ? const Uuid().v4() : contact.id,
      name: contact.name,
      category: contact.category,
      phoneNumber: contact.phoneNumber,
      alternativeNumber: contact.alternativeNumber,
      designation: contact.designation,
      orderIndex: insertIndex,
    );

    _contacts.insert(insertIndex, newContact);
    
    // Update all order indices from insertIndex onwards
    WriteBatch batch = _firestore.batch();
    for (int i = insertIndex; i < _contacts.length; i++) {
      final c = _contacts[i];
      final updatedC = ContactModel(
        id: c.id, name: c.name, category: c.category, phoneNumber: c.phoneNumber,
        alternativeNumber: c.alternativeNumber, designation: c.designation, orderIndex: i
      );
      _contacts[i] = updatedC;
      batch.set(_firestore.collection('contacts').doc(c.id), updatedC.toMap());
    }

    notifyListeners();
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error adding contact to firebase: $e');
    }
  }

  Future<void> updateContact(ContactModel updatedContact) async {
    final index = _contacts.indexWhere((c) => c.id == updatedContact.id);
    if (index != -1) {
      final oldContact = _contacts[index];
      if (oldContact.category != updatedContact.category) {
        // We delete from current position and re-insert alphabetically in new category
        _contacts.removeAt(index);
        await _firestore.collection('contacts').doc(updatedContact.id).delete();
        
        // Re-sync all indices down
        WriteBatch batch = _firestore.batch();
        for (int i = index; i < _contacts.length; i++) {
           final c = _contacts[i];
           final updatedC = ContactModel(
             id: c.id, name: c.name, category: c.category, phoneNumber: c.phoneNumber,
             alternativeNumber: c.alternativeNumber, designation: c.designation, orderIndex: i
           );
           _contacts[i] = updatedC;
           batch.set(_firestore.collection('contacts').doc(c.id), updatedC.toMap());
        }
        await batch.commit();
        
        await addContact(updatedContact); 
      } else {
        // Just update in place, keep order index
        ContactModel c = ContactModel(
           id: updatedContact.id, name: updatedContact.name, category: updatedContact.category, 
           phoneNumber: updatedContact.phoneNumber, alternativeNumber: updatedContact.alternativeNumber, 
           designation: updatedContact.designation, orderIndex: oldContact.orderIndex
        );
        _contacts[index] = c;
        notifyListeners();
        await _firestore.collection('contacts').doc(c.id).update(c.toMap());
      }
    }
  }

  Future<void> deleteContact(String id) async {
    final index = _contacts.indexWhere((c) => c.id == id);
    if (index != -1) {
      _contacts.removeAt(index);
      notifyListeners();

      WriteBatch batch = _firestore.batch();
      batch.delete(_firestore.collection('contacts').doc(id));
      
      // Update order index for the remaining items
      for (int i = index; i < _contacts.length; i++) {
        final c = _contacts[i];
        final updatedC = ContactModel(
          id: c.id, name: c.name, category: c.category, phoneNumber: c.phoneNumber,
          alternativeNumber: c.alternativeNumber, designation: c.designation, orderIndex: i
        );
        _contacts[i] = updatedC;
        batch.set(_firestore.collection('contacts').doc(c.id), updatedC.toMap());
      }

      try {
        await batch.commit();
      } catch (e) {
         debugPrint('Error deleting contact from firebase: $e');
      }
    }
  }

  Future<void> reorderWithinCategory(String category, int oldIndex, int newIndex) async {
    final catItems = _contacts.where((c) => c.category == category).toList();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = catItems.removeAt(oldIndex);
    catItems.insert(newIndex, item);

    List<ContactModel> newList = [];
    int catCounter = 0;
    for (var c in _contacts) {
      if (c.category == category) {
        newList.add(catItems[catCounter]);
        catCounter++;
      } else {
        newList.add(c);
      }
    }
    
    // Apply new orderIndex
    WriteBatch batch = _firestore.batch();
    for (int i = 0; i < newList.length; i++) {
      final c = newList[i];
      final updatedC = ContactModel(
        id: c.id, name: c.name, category: c.category, phoneNumber: c.phoneNumber,
        alternativeNumber: c.alternativeNumber, designation: c.designation, orderIndex: i
      );
      newList[i] = updatedC;
      batch.set(_firestore.collection('contacts').doc(c.id), updatedC.toMap());
    }
    
    _contacts = newList;
    notifyListeners();
    
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Error reordering in firebase: $e');
    }
  }
}
