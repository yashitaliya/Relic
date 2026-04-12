import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../widgets/scale_button.dart';
import '../widgets/styled_dialog.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SafeArea(
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF6B3E26),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Help & Feedback',
                          style: TextStyle(
                            color: Color(0xFF6B3E26),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: 110 + MediaQuery.of(context).padding.top + 16,
          bottom: 40,
          left: 16,
          right: 16,
        ),
        children: [
          _buildSectionTitle('Help Center'),
          const SizedBox(height: 12),
          _buildHelpCenterCard(),
          const SizedBox(height: 32),
          _buildSectionTitle('Feedback'),
          const SizedBox(height: 12),
          _buildFeedbackCard(context),
          const SizedBox(height: 32),
          _buildSectionTitle('Contact Us'),
          const SizedBox(height: 12),
          _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF6B3E26),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildHelpCenterCard() {
    return _buildCard(
      children: [
        _buildExpandableItem(
          'How to hide photos?',
          'Select photos → tap the Lock icon → photos move to Vault. Access the Vault from the More tab.',
        ),
        _buildDivider(),
        _buildExpandableItem(
          'How to create albums?',
          'Open Albums → tap the + button → choose photos → save your new album.',
        ),
        _buildDivider(),
        _buildExpandableItem(
          'Recover deleted photos',
          'Check Recently Deleted in the More tab. Items stay for 30 days.',
        ),
        _buildDivider(),
        _buildExpandableItem(
          'Search photos',
          'Search by date, location, objects, or categories like Selfies and Screenshots.',
        ),
      ],
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return _buildCard(
      children: [
        _buildActionItem(
          context,
          'Report a bug',
          Icons.bug_report_outlined,
          () => _showFeedbackDialog(context, 'Report a bug'),
        ),
        _buildDivider(),
        _buildActionItem(
          context,
          'Request a feature',
          Icons.lightbulb_outline,
          () => _showFeedbackDialog(context, 'Request a feature'),
        ),
        _buildDivider(),
        _buildActionItem(context, 'Rate the app', Icons.star_outline, () {
          // Placeholder for in-app review
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening store for review...')),
          );
        }),
        _buildDivider(),
        _buildActionItem(
          context,
          'Feedback History',
          Icons.history,
          () => _showFeedbackHistory(context),
        ),
      ],
    );
  }

  Widget _buildContactCard() {
    return _buildCard(
      children: [
        _buildActionItem(
          null, // Context not needed for URL launcher
          'Email Support',
          Icons.email_outlined,
          () => _launchEmail(),
        ),
      ],
    );
  }

  Widget _buildExpandableItem(String title, String content) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext? context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ScaleButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF37121).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFFF37121), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.withValues(alpha: 0.1),
      indent: 16,
      endIndent: 16,
    );
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'italiyayash2006@gmail.com',
      query: _encodeQueryParameters(<String, String>{
        'subject': 'Relic Gallery Support',
      }),
    );

    if (!await launchUrl(emailLaunchUri)) {
      debugPrint('Could not launch email');
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  void _showFeedbackDialog(BuildContext context, String title) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6B3E26),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF37121),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF37121),
                    width: 2,
                  ),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final feedbackTitle = titleController.text;
              final feedbackDescription = descriptionController.text;

              Navigator.pop(context);

              // Save locally
              try {
                final prefs = await SharedPreferences.getInstance();
                final List<String> history =
                    prefs.getStringList('feedback_history') ?? [];
                final feedbackEntry = jsonEncode({
                  'type': title,
                  'title': feedbackTitle,
                  'description': feedbackDescription,
                  'timestamp': DateTime.now().toIso8601String(),
                });
                history.add(feedbackEntry);
                await prefs.setStringList('feedback_history', history);
              } catch (e) {
                debugPrint('Error saving feedback locally: $e');
              }

              // Launch Email
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'italiyayash2006@gmail.com',
                query: _encodeQueryParameters(<String, String>{
                  'subject': '$title: $feedbackTitle',
                  'body': feedbackDescription,
                }),
              );

              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              } else {
                debugPrint('Could not launch email');
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening email client...')),
                );
              }
            },
            child: const Text(
              'Submit',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackHistory(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    // Make a mutable copy to be safe, though getStringList usually returns a mutable list.
    final List<String> history = (prefs.getStringList('feedback_history') ?? [])
        .toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Feedback History'),
            content: SizedBox(
              width: double.maxFinite,
              child: history.isEmpty
                  ? const Text('No feedback history found.')
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        // Reverse order to show newest first
                        final entryJson = history[history.length - 1 - index];
                        try {
                          final entry =
                              jsonDecode(entryJson) as Map<String, dynamic>;
                          final timestamp = DateTime.parse(entry['timestamp']);
                          final dateStr = DateFormat(
                            'MMM d, yyyy h:mm a',
                          ).format(timestamp);

                          return ListTile(
                            title: Text(
                              entry['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry['description'] ?? ''),
                                const SizedBox(height: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          );
                        } catch (e) {
                          return const ListTile(
                            title: Text('Error parsing entry'),
                          );
                        }
                      },
                    ),
            ),
            actions: [
              if (history.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await prefs.remove('feedback_history');
                    setState(() {
                      history.clear();
                    });
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }
}
