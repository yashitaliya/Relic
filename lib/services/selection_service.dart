import 'package:flutter/foundation.dart';

class SelectionService {
  static final SelectionService instance = SelectionService._();
  SelectionService._();

  final ValueNotifier<bool> isSelectionMode = ValueNotifier(false);

  void startSelection() {
    isSelectionMode.value = true;
  }

  void endSelection() {
    isSelectionMode.value = false;
  }
}
