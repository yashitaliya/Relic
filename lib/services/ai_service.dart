class AiService {
  static final List<_FaqRule> _faqRules = [
    _FaqRule(
      keywords: ['hide', 'vault', 'private', 'lock photo'],
      answer:
          'To hide photos: select items, tap the lock icon, and they move to Vault. Open More > Vault to view them after authentication.',
    ),
    _FaqRule(
      keywords: ['unhide', 'restore from vault', 'bring back from vault'],
      answer:
          'Open More > Vault, select items, then choose unhide/restore. They will be added back to your gallery.',
    ),
    _FaqRule(
      keywords: ['delete photo', 'remove photo', 'trash'],
      answer:
          'Select photos and tap delete. Deleted items go to Recently Deleted and can be restored before permanent removal.',
    ),
    _FaqRule(
      keywords: ['recently deleted', 'recover', 'restore deleted'],
      answer:
          'Go to More > Recently Deleted, select media, then tap restore to recover it.',
    ),
    _FaqRule(
      keywords: ['favorite', 'heart', 'liked photos'],
      answer:
          'Tap the heart action to mark favorites. You can see all favorites in More > Favorites.',
    ),
    _FaqRule(
      keywords: ['rename', 'change name'],
      answer:
          'Select one item, open the 3-dot action menu, then choose rename.',
    ),
    _FaqRule(
      keywords: ['move photo', 'transfer photo', 'change folder'],
      answer:
          'Select photos, open the 3-dot action menu, then choose move and pick the destination album.',
    ),
    _FaqRule(
      keywords: ['copy photo', 'duplicate photo'],
      answer:
          'Select photos, open the 3-dot action menu, then choose copy and select destination album.',
    ),
    _FaqRule(
      keywords: ['share', 'send photo'],
      answer:
          'Select one or more items and tap the share icon in selection mode.',
    ),
    _FaqRule(
      keywords: ['select all', 'multi select', 'multiple photos'],
      answer:
          'Enter selection mode with long-press, then use the select-all icon in the top bar.',
    ),
    _FaqRule(
      keywords: ['search photo', 'find photo', 'search'],
      answer:
          'Use the Search tab to find media by text, category, date, or other filters.',
    ),
    _FaqRule(
      keywords: ['albums', 'folder', 'create album', 'new album'],
      answer:
          'Open Albums tab to create and manage folders. You can organize photos with move/copy actions.',
    ),
    _FaqRule(
      keywords: ['permission', 'photos access', 'allow access'],
      answer:
          'If photos are missing, check gallery permissions in system settings and allow full access for Relic.',
    ),
    _FaqRule(
      keywords: ['missing photos', 'photos not showing', 'not visible'],
      answer:
          'Check Vault and Recently Deleted first, then refresh app permissions and reopen the app.',
    ),
    _FaqRule(
      keywords: ['sort', 'order by date', 'newest', 'oldest'],
      answer:
          'Use the sort option in the top bar to switch between newest, oldest, or name sorting.',
    ),
    _FaqRule(
      keywords: ['grid', 'columns', 'thumbnail size', 'photo size'],
      answer:
          'You can change grid size in Settings to show more or fewer items per row.',
    ),
    _FaqRule(
      keywords: ['dark mode', 'theme', 'light mode'],
      answer:
          'Theme options are available in Settings where you can switch appearance preferences.',
    ),
    _FaqRule(
      keywords: ['app lock', 'pin', 'biometric', 'face id', 'fingerprint'],
      answer:
          'Vault and app privacy features use your secure authentication settings. Configure them in Settings and Vault flow.',
    ),
    _FaqRule(
      keywords: ['ai image', 'generate image', 'image generator'],
      answer:
          'Use the AI tab to generate images from text prompts, then save results directly to gallery.',
    ),
    _FaqRule(
      keywords: ['save generated image', 'download ai image'],
      answer: 'After generation, tap save to add the image to your gallery.',
    ),
    _FaqRule(
      keywords: ['slow', 'lag', 'performance', 'app slow'],
      answer:
          'Try clearing heavy selections, ensure storage space is available, and reopen the app after a full refresh.',
    ),
    _FaqRule(
      keywords: ['crash', 'not working', 'error'],
      answer:
          'Please retry after reopening the app and checking permissions. If it persists, share the exact action and error text.',
    ),
    _FaqRule(
      keywords: ['backup', 'cloud', 'sync'],
      answer:
          'Relic manages local gallery organization. Cloud backup behavior depends on your device photo backup services.',
    ),
    _FaqRule(
      keywords: ['storage', 'space', 'free up'],
      answer:
          'Review large videos, remove unwanted items, and clear Recently Deleted to reclaim space.',
    ),
    _FaqRule(
      keywords: ['contact', 'feedback', 'help'],
      answer:
          'Open More > Help & Feedback to report issues or send suggestions.',
    ),
    _FaqRule(
      keywords: ['what can you do', 'features', 'about app'],
      answer:
          'I can help with Relic features: gallery navigation, search, albums, favorites, vault, restore, settings, and AI image generation.',
    ),
  ];

  void clearConversation() {}

  Future<String> sendMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty) return 'Please enter a message.';

    final normalized = _normalize(text);
    _FaqRule? bestRule;
    int bestScore = 0;

    for (final rule in _faqRules) {
      final score = rule.keywords
          .where((keyword) => normalized.contains(_normalize(keyword)))
          .length;
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
      }
    }

    if (bestRule != null && bestScore > 0) {
      return bestRule.answer;
    }

    return 'I can help with Relic Gallery features only. Try asking about Vault, albums, search, favorites, Recently Deleted, sharing, or settings.';
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class _FaqRule {
  final List<String> keywords;
  final String answer;

  const _FaqRule({required this.keywords, required this.answer});
}
