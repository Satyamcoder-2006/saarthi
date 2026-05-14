import 'package:fuzzy/fuzzy.dart';
import '../models/contact.dart';

class FuzzyMatcher {
  static List<Contact> searchContacts(String query, List<Contact> contacts) {
    if (query.isEmpty) return contacts;

    final fuse = Fuzzy<Contact>(
      contacts,
      options: FuzzyOptions(
        keys: [
          WeightedKey<Contact>(
            name: 'name',
            getter: (Contact x) => x.name,
            weight: 1,
          ),
        ],
        threshold: 0.4,
      ),
    );

    final results = fuse.search(query);
    return results.map((r) => r.item).toList();
  }
}
