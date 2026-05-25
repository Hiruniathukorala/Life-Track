# 🌿 LifeTrack — Health & Lifestyle Mobile Application

> A cross-platform Flutter application for holistic health and lifestyle tracking, built as a Final Year project at NSBM Green University.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=flat&logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth-FFCA28?style=flat&logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey?style=flat)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/License-Academic-green?style=flat)]()

---

## 📖 About

**LifeTrack** is a comprehensive health and lifestyle mobile application designed to help users monitor and improve their daily wellbeing. The application provides an all-in-one platform for tracking physical activity, hydration, sleep patterns, and personal wellness goals — empowering users to build healthier habits through data-driven insights and intuitive design.

The project was developed as a Final Year project (2025–2026) at NSBM Green University, Department of Software Engineering. It follows a research-driven design methodology — from user research and persona development through to high-fidelity prototyping, full-stack implementation, and testing.

---

## ✨ Features

### 🏃 Activity & Fitness Tracking
- Daily activity logging with step count and exercise duration
- Goal setting and progress monitoring with visual indicators
- Historical activity data with weekly and monthly trends

### 💧 Hydration Monitoring
- Daily water intake tracking with customisable hydration goals
- Smart reminders to maintain optimal hydration throughout the day
- Visual progress tracker with intake history

### 😴 Sleep Tracking
- Sleep duration logging and quality assessment
- Sleep pattern analysis with nightly and weekly insights
- Personalised sleep goal recommendations

### 😊 Face-Based Mood Detection
- On-device face analysis using **Google ML Kit** (no internet or API key required)
- Real-time emotional state detection via front camera
- Mood history log to identify wellbeing trends over time

### 🔔 Habit Alarms & Reminders
- Custom local notifications for habits, hydration, sleep, and activity reminders
- Timezone-aware scheduling using `flutter_local_notifications` and `timezone`
- Fully offline — no server dependency for alarm management

### 🔐 Authentication & Cloud Sync
- Secure user authentication via **Firebase Auth** (email/password)
- Real-time data sync across devices with **Cloud Firestore**
- User-specific data isolation with Firestore security rules

### 🎨 UI/UX Design
- Clean, accessible Material 3 interface designed in Figma
- Inclusive design principles supporting varying levels of digital literacy
- Responsive layouts across Android, iOS, and Web platforms

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend / Database | Firebase Firestore |
| Authentication | Firebase Auth |
| On-Device AI | Google ML Kit — Face Detection |
| Notifications | flutter_local_notifications + timezone |
| Camera | Flutter Camera Plugin |
| Networking | HTTP (Dart) |
| State Management | Flutter built-in (setState / Future) |
| Design Tool | Figma |
| Version Control | Git & GitHub |

---

## 🏗️ Project Structure

```
life_track/
├── android/              # Android platform-specific code
├── ios/                  # iOS platform-specific code
├── web/                  # Web platform entry point
├── linux/                # Linux desktop support
├── macos/                # macOS desktop support
├── windows/              # Windows desktop support
├── lib/                  # Main Dart source code
│   ├── main.dart         # App entry point
│   ├── screens/          # UI screens (home, activity, sleep, hydration, mood)
│   ├── widgets/          # Reusable UI components
│   ├── models/           # Data models
│   ├── services/         # Firebase, notification, and camera services
│   └── utils/            # Helper functions and constants
├── test/                 # Unit and widget tests
├── firestore.rules       # Firestore security rules
├── pubspec.yaml          # Dependencies and project config
└── ARCHITECTURE.md       # Detailed system architecture
```

---

## 🚀 Getting Started

### Prerequisites

Make sure you have the following installed:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.6.1`
- [Dart SDK](https://dart.dev/get-dart) `^3.6.1`
- [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extension
- A Firebase project (see setup below)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Hiruniathukorala/Life-Track.git
   cd Life-Track
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a project at [Firebase Console](https://console.firebase.google.com)
   - Enable **Authentication** (Email/Password) and **Cloud Firestore**
   - Download `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS)
   - Place them in `android/app/` and `ios/Runner/` respectively
   - Deploy Firestore security rules:
     ```bash
     firebase deploy --only firestore:rules
     ```

4. **Run the app**
   ```bash
   # For Android/iOS
   flutter run

   # For Web
   flutter run -d chrome

   # For a specific device
   flutter devices
   flutter run -d <device_id>
   ```

---

## 📐 Architecture

LifeTrack follows a **layered architecture** pattern:

```
┌─────────────────────────────────┐
│         Presentation Layer      │  Screens, Widgets, UI components
├─────────────────────────────────┤
│         Business Logic Layer    │  Controllers, State management
├─────────────────────────────────┤
│         Service Layer           │  Firebase, ML Kit, Notifications
├─────────────────────────────────┤
│         Data Layer              │  Firestore models, local storage
└─────────────────────────────────┘
```

For a detailed breakdown of system design decisions, data flow, and component relationships, see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

Tests are located in the `/test` directory and cover core widget rendering and service logic.

---

## 📦 Key Dependencies

```yaml
firebase_core: ^4.0.0          # Firebase initialisation
firebase_auth: ^6.0.0          # User authentication
cloud_firestore: ^6.0.0        # Real-time NoSQL database
camera: ^0.11.0                # In-app camera access
google_mlkit_face_detection: ^0.11.0   # On-device face & mood analysis
flutter_local_notifications: ^18.0.0   # Local habit reminders
timezone: ^0.9.4               # Timezone-aware scheduling
http: ^1.2.0                   # HTTP networking
```

---

## 🎨 Design Process

The UI/UX was developed following a research-driven design approach:

1. **User Research** — Surveys and interviews to understand health tracking needs
2. **Personas & Journey Maps** — Defining user types and key interaction flows
3. **Wireframing** — Low-fidelity sketches and structural layouts
4. **High-Fidelity Prototypes** — Designed in Figma with Material 3 guidelines
5. **Usability Testing** — Iterative feedback cycles to improve task completion and accessibility
6. **Implementation** — Translating designs into responsive Flutter components

---

## 👩‍💻 Author

**Hiruni Athukorala**
BSc (Hons) Software Engineering — NSBM Green University (2023–2026)

- 🔗 [LinkedIn](https://www.linkedin.com/in/hiruni-athukorala/)
- 💻 [GitHub](https://github.com/Hiruniathukorala)
- 📧 hirunilalithya2003@gmail.com

---

## 📄 License

This project was developed as an academic final year project at NSBM Green University. All rights reserved © 2026 Hiruni Athukorala.

---

<p align="center">Built with 💚 using Flutter & Firebase</p>
