<div align="center">

# 📸 Relic

**A modern Flutter gallery app focused on clean organization, privacy, and smooth UX.**

[![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10%2B-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-success)](#)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[🎬 Demo Video](https://github.com/user-attachments/assets/fbb4593a-ebc0-4a8d-ac60-6ca2e013fe64)

</div>

---

## ✨ Highlights

- 🖼️ Beautiful photo timeline and album browsing
- 🧭 Custom floating bottom navigation (app-themed)
- 🔎 Fast search and smart indexing
- 🔐 Vault for private media
- ♻️ Recently Deleted flow
- 🤖 Local AI assistant for app/gallery help (no external AI API required)
- ⚡ Smooth animations and responsive interactions

---

## 🧩 Features

### Gallery & Albums
- Photo grid with adjustable size
- Timeline grouping by date
- Album listing and album detail views
- Copy/move between albums
- Multi-select actions (share, move, copy, hide, delete)

### Privacy & Safety
- Vault with local protection flow
- Recently Deleted management
- iOS-aware behavior for operations supported by Photos framework

### Search & Assistant
- Search photos and metadata quickly
- Local FAQ-style assistant to answer common app/gallery questions
- AI image generation screen (Pollinations-based)

### UI/UX
- Orange + cream theme system
- Custom splash experience
- Modern floating navigation and app bars
- Consistent motion and transitions across screens

---

## 📱 Platform Behavior Notes

Relic supports both Android and iOS, with platform-correct media behavior:

- **Android:** SAF / file-based operations where applicable
- **iOS:** Photos-framework-based album operations (copy/move semantics differ from filesystem)
- Some actions (like true rename in iOS Photos library) are constrained by platform APIs

---

## 🏗️ Tech Stack

- **Framework:** Flutter
- **Language:** Dart
- **Media Access:** `photo_manager`
- **Storage/Prefs:** `shared_preferences`, `sqflite`, secure storage
- **Image/Video:** `photo_view`, `media_kit`, `pro_image_editor`
- **Other:** sharing, geocoding, permissions, encryption utilities

---

## 📂 Project Structure

```text
lib/
├── main.dart
├── theme/
│   └── app_theme.dart
├── models/
│   └── photo_model.dart
├── services/
│   ├── ai_service.dart
│   ├── auth_service.dart
│   ├── cache_service.dart
│   ├── classification_service.dart
│   ├── file_manager_service.dart
│   ├── image_generation_service.dart
│   ├── photo_service.dart
│   ├── saf_service.dart
│   ├── search_data_service.dart
│   ├── selection_service.dart
│   ├── settings_service.dart
│   ├── trash_service.dart
│   └── vault_service.dart
├── screens/
│   ├── ai_assistant_screen.dart
│   ├── album_photos_screen.dart
│   ├── albums_screen.dart
│   ├── favorites_gallery_screen.dart
│   ├── help_feedback_screen.dart
│   ├── home_screen.dart
│   ├── image_generation_screen.dart
│   ├── more_screen.dart
│   ├── photo_detail_screen.dart
│   ├── recently_deleted_screen.dart
│   ├── saf_setup_screen.dart
│   ├── search_screen.dart
│   ├── settings_screen.dart
│   ├── splash_screen.dart
│   ├── vault_auth_screen.dart
│   ├── vault_import_screen.dart
│   ├── vault_screen.dart
│   ├── vault_viewer_screen.dart
│   └── video_player_screen.dart
├── widgets/
│   ├── ai_floating_button.dart
│   ├── app_lock_wrapper.dart
│   ├── custom_bottom_nav.dart
│   ├── custom_notification.dart
│   ├── photo_grid.dart
│   ├── photo_grid_item.dart
│   └── radial_menu.dart
├── database/
│   └── vault_database.dart
└── utils/
    └── animation_utils.dart
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10+
- Dart SDK 3.10+
- Android Studio / VS Code
- Android/iOS device or simulator

### Installation

```bash
git clone https://github.com/yashitaliya/Relic.git
cd relic
flutter pub get
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (on macOS with Xcode)
flutter build ios --release
```

---

## ⚙️ Configuration

### App icon/assets
- `assets/relic_app_icon.png`
- `assets/logo/relic_logo.png`

### Common settings available in-app
- Start page
- Grid size
- Cache clear
- App lock options

---

## 🧪 Quality Commands

```bash
flutter analyze
flutter test
```

---

## 🗺️ Roadmap

- [ ] Improve folder/album workflows further
- [ ] Expand local AI knowledge base
- [ ] Add richer onboarding/tutorial
- [ ] Add optional cloud backup/sync
- [ ] More personalization options

---

## 👨‍💻 Developer

**Yash Italiya**

- GitHub: [@yashitaliya](https://github.com/yashitaliya)

---

## 🤝 Contributing

Contributions, suggestions, and feedback are welcome.

1. Fork the repo
2. Create a feature branch
3. Commit your changes
4. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License**.  
If you add a `LICENSE` file, this badge and section will be fully active.

---

<div align="center">

Made with ❤️ using Flutter

</div>
