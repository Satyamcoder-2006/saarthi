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
  bool isLoading = false;

  ContactsProvider({required this.apiService, required this.storageService});

  Future<void> loadContacts() async {
    // 1. Load from local Hive cache first (instant)
    _allContacts = storageService.contactsBox.values.toList();
    filteredContacts = List.from(_allContacts);
    notifyListeners();

    // 2. Sync from backend if available
    if (apiService.isInitialized) {
      try {
        final serverContacts = await apiService.getContacts();
        if (serverContacts.isNotEmpty) {
          _allContacts = serverContacts;
          filteredContacts = List.from(_allContacts);
          await storageService.contactsBox.clear();
          await storageService.contactsBox.addAll(serverContacts);
          notifyListeners();
        }
      } catch (e) {
        // Keep local cache if backend fails
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

  Future<void> addContact(
    String name,
    String phone,
    String? whatsapp,
    bool isEmergency,
  ) async {
    isLoading = true;
    notifyListeners();

    final contact = Contact(
      id: const Uuid().v4(),
      name: name.trim(),
      phone: phone.trim(),
      whatsappNumber: whatsapp?.trim(),
      isEmergency: isEmergency,
    );

    _allContacts.add(contact);
    filteredContacts = List.from(_allContacts);
    await storageService.contactsBox.add(contact);

    if (apiService.isInitialized) {
      try {
        await apiService.addContact(contact);
      } catch (_) {}
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteContact(Contact contact) async {
    _allContacts.removeWhere((c) => c.id == contact.id);
    filteredContacts = List.from(_allContacts);

    // Remove from local Hive
    final key = storageService.contactsBox.keys.firstWhere(
      (k) => storageService.contactsBox.get(k)?.id == contact.id,
      orElse: () => null,
    );
    if (key != null) await storageService.contactsBox.delete(key);

    // Remove from backend
    if (apiService.isInitialized) {
      try {
        await apiService.deleteContact(contact.id);
      } catch (_) {}
    }

    notifyListeners();
  }
}
