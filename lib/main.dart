import 'dart:io';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'add_contact_screen.dart';
import 'launcher_utils.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WeMetApp());
}

class WeMetApp extends StatelessWidget {
  const WeMetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeMet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ContactModel> _contacts = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  Future<void> _refreshContacts() async {
    final data = await DBHelper.instance.searchContacts(_searchQuery);
    setState(() => _contacts = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WeMet')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name, hobby, company, or topic...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _refreshContacts();
              },
            ),
          ),
          Expanded(
            child: _contacts.isEmpty
                ? const Center(child: Text('No connections found.'))
                : ListView.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final person = _contacts[index];
                      final hasPhone = person.phone != null && person.phone!.trim().isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: person.photoPath != null
                                ? FileImage(File(person.photoPath!))
                                : null,
                            child: person.photoPath == null
                                ? Text(person.name.isNotEmpty ? person.name[0] : '?')
                                : null,
                          ),
                          title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            [person.company, person.hobbies].where((e) => e != null && e.isNotEmpty).join(' • '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: hasPhone
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
                                      tooltip: 'WhatsApp',
                                      onPressed: () => LauncherUtils.openWhatsApp(person.phone!),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.phone_outlined, color: Colors.indigo),
                                      tooltip: 'Call',
                                      onPressed: () => LauncherUtils.makeCall(person.phone!),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: () => _showDetailsDialog(context, person),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContactScreen()),
          );
          if (result == true) _refreshContacts();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, ContactModel person) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(person.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.photoPath != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(person.photoPath!), height: 160, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 12),
              if (person.phone?.isNotEmpty == true) Text('📞 Phone: ${person.phone}'),
              if (person.email?.isNotEmpty == true) Text('✉️ Email: ${person.email}'),
              if (person.company?.isNotEmpty == true) Text('🏢 Company: ${person.company}'),
              if (person.residence?.isNotEmpty == true) Text('📍 Residence: ${person.residence}'),
              if (person.familyNotes?.isNotEmpty == true) Text('👨‍👩‍👧 Family: ${person.familyNotes}'),
              if (person.hobbies?.isNotEmpty == true) Text('🎾 Hobbies: ${person.hobbies}'),
              const Divider(height: 24),
              Text('🗓️ Last Met: ${person.lastMetDate ?? "N/A"}'),
              const SizedBox(height: 4),
              Text('💬 Discussed: ${person.lastDiscussion ?? "No notes."}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}
