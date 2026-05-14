import 'package:flutter/material.dart';
import '../../core/models/contact.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/fuzzy_matcher.dart';
import 'package:uuid/uuid.dart';

class ContactsProvider extends ChangeNotifier {
  final ApiService apiService;
  final StorageService storageService;

  List<Contact> _allContacts = [];
  List<Contact> filteredContacts = [];

  ContactsProvider({required this.apiService, required this.storageService});

  Future<void> loadContacts() async {
    // 1. Load from local Hive cache
    _allContacts = storageService.contactsBox.values.toList();
    filteredContacts = List.from(_allContacts);
    notifyListeners();

    // 2. Try fetching from backend if connected
    if (apiService.isInitialized) {
      try {
        final serverContacts = await apiService.getContacts();
        if (serverContacts.isNotEmpty) {
          _allContacts = serverContacts;
          filteredContacts = List.from(_allContacts);
          // Update cache
          await storageService.contactsBox.clear();
          await storageService.contactsBox.addAll(serverContacts);
          notifyListeners();
        }
      } catch (e) {
        print("Error fetching contacts from server: $e");
      }
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      filteredContacts = List.from(_allContacts);
    } else {
      filteredContacts = FuzzyMatcher.searchContacts(query, _allContacts);
    }
    notifyListeners();
  }

  Future<void> addContact(String name, String phone, String? whatsapp, bool isEmergency) async {
    final contact = Contact(
      id: const Uuid().v4(),
      name: name,
      phone: phone,
      whatsappNumber: whatsapp,
      isEmergency: isEmergency,
    );

    _allContacts.add(contact);
    filteredContacts = List.from(_allContacts);
    await storageService.contactsBox.add(contact);
    
    if (apiService.isInitialized) {
      try {
        await apiService.addContact(contact);
      } catch (e) {
        print("Could not sync new contact to server: $e");
      }
    }
    
    notifyListeners();
  }
}
