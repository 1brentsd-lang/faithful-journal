import 'package:flutter/foundation.dart';

/// Tracks whether the currently-active editor has unsaved progress.
///
/// This is intentionally simple (single-owner) so the tab shell can gate
/// navigation without coupling to specific screens.
class UnsavedChangesService extends ChangeNotifier {
  String? _ownerKey;
  bool _hasUnsaved = false;

  String? get ownerKey => _ownerKey;
  bool get hasUnsaved => _hasUnsaved;

  /// Claim ownership for a screen that wants to report unsaved changes.
  ///
  /// Calling this resets the dirty state for that owner.
  void claim(String ownerKey) {
    _ownerKey = ownerKey;
    _hasUnsaved = false;
    notifyListeners();
  }

  void markDirty(String ownerKey) {
    if (_ownerKey != ownerKey) return;
    if (_hasUnsaved) return;
    _hasUnsaved = true;
    notifyListeners();
  }

  void clear(String ownerKey) {
    if (_ownerKey != ownerKey) return;
    _ownerKey = null;
    _hasUnsaved = false;
    notifyListeners();
  }

  /// Use with care: clears whatever owner is currently active.
  void clearAny() {
    if (_ownerKey == null && !_hasUnsaved) return;
    _ownerKey = null;
    _hasUnsaved = false;
    notifyListeners();
  }
}
