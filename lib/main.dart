import 'dart:io';
import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'add_contact_screen.dart';
import 'launcher_utils.dart';
import 'contact_sync_utils.dart';

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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7),
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF25D366),
          surface: const Color(0xFFF8F9FE),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F4F9),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
      ),
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
  bool _isSyncing = false;

  final List<Color> _avatarColors = [
    const Color(0xFF6C5CE7),
    const Color(0xFF00B894),
    const Color(0xFFE17055),
    const Color(0xFF0984E3),
    const Color(0xFFE84393),
    const Color(0xFFFDCB6E),
  ];

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  Future<void> _refreshContacts() async {
    final data = await DBHelper.instance.searchContacts(_searchQuery);
    setState(() => _contacts = data);
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    final count = await ContactSyncUtils.syncDeviceContacts();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00B894),
          content: Text('$count new contacts imported successfully!'),
        ),
      );
      _refreshContacts();
    }
  }

  void _showMergeDialog(ContactModel targetContact) {
    ContactModel? selectedMergeCandidate;
    final otherContacts = _contacts.where((c) => c.id != targetContact.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Merge with ${targetContact.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select duplicate contact to combine notes and history into this profile:'),
              const SizedBox(height: 12),
              DropdownButton<ContactModel>(
                isExpanded: true,
                hint: const Text('Pick duplicate contact'),
                value: selectedMergeCandidate,
                items: otherContacts.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (val) => setDialogState(() => selectedMergeCandidate = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
              onPressed: selectedMergeCandidate == null
                  ? null
                  : () async {
                      await DBHelper.instance.mergeContacts(targetContact, selectedMergeCandidate!);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _refreshContacts();
                    },
              child: const Text('Merge'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        elevation: 0,
        title: const Text('WeMet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22)),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync, color: Colors.white),
            tooltip: 'Sync Phone Contacts',
            onPressed: _isSyncing ? null : _handleSync,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF6C5CE7),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.2),
                hintText: 'Search by name, hobby, company, or note...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchQuery = '';
                          _refreshContacts();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _refreshContacts();
              },
            ),
          ),
          Expanded(
            child: _contacts.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No connections yet.\nTap + or Sync to add contacts!' : 'No results found.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final person = _contacts[index];
                      final color = _avatarColors[index % _avatarColors.length];
                      final hasPhone = person.phone != null && person.phone!.trim().isNotEmpty;

                      return Dismissible(
                        key: Key(person.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: const Color(0xFFE17055),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Contact'),
                              content: Text('Remove ${person.name} from WeMet?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) async {
                          await DBHelper.instance.deleteContact(person.id!);
                          _refreshContacts();
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color,
                              backgroundImage: person.photoPath != null ? FileImage(File(person.photoPath!)) : null,
                              child: person.photoPath == null
                                  ? Text(
                                      person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            subtitle: Text(
                              [person.company, person.hobbies].where((e) => e != null && e.isNotEmpty).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasPhone) ...[
                                  IconButton(
                                    icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                                    tooltip: 'Chat on WhatsApp',
                                    onPressed: () => LauncherUtils.openWhatsApp(person.phone!),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.phone, color: Color(0xFF6C5CE7)),
                                    tooltip: 'Call Phone',
                                    onPressed: () => LauncherUtils.makeCall(person.phone!),
                                  ),
                                ],
                                PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'merge') _showMergeDialog(person);
                                    if (val == 'delete') {
                                      DBHelper.instance.deleteContact(person.id!);
                                      _refreshContacts();
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'merge', child: Text('Merge with duplicate')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete contact', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _showDetailsDialog(context, person),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('New Connection'),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddContactScreen()),
          );
          if (result == true) _refreshContacts();
        },
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, ContactModel person) {
    final hasPhone = person.phone != null && person.phone!.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person.photoPath != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(person.photoPath!), height: 170, width: double.infinity, fit: BoxFit.cover),
                  ),
                ),
              const SizedBox(height: 12),
              if (hasPhone) ...[
                Text('📞 Phone: ${person.phone}'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Message on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => LauncherUtils.openWhatsApp(person.phone!),
                ),
                const SizedBox(height: 8),
              ],
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
