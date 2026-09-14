import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'db_helper.dart';

class ContactSyncUtils {
  static Future<int> syncDeviceContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) return 0;

    final deviceContacts = await FastContacts.getAllContacts();
    final existing = await DBHelper.instance.searchContacts('');
    final existingPhones = existing.map((c) => c.phone?.replaceAll(RegExp(r'[^0-9]'), '')).toSet();

    int importedCount = 0;
    for (var contact in deviceContacts) {
      final phone = contact.phones.isNotEmpty ? contact.phones.first.number : null;
      final cleanPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanPhone != null && existingPhones.contains(cleanPhone)) {
        continue;
      }

      final newContact = ContactModel(
        name: contact.displayName.isNotEmpty ? contact.displayName : 'Unknown',
        phone: phone,
        email: contact.emails.isNotEmpty ? contact.emails.first.address : null,
        company: contact.organization?.company,
        lastMetDate: DateTime.now().toIso8601String().substring(0, 10),
        lastDiscussion: 'Imported from Phone Contacts',
      );

      await DBHelper.instance.insertContact(newContact);
      importedCount++;
    }

    return importedCount;
  }
}
