# LifeTrack Prototype Architecture

This document outlines the architecture for the LifeTrack Flutter application.

## Feature List
1.  **Authentication**: Firebase Auth (Email/Password & Google Sign-In).
2.  **Unified Logging**: Streamlined interface to log activities, habits, and moods in under 1 minute.
3.  **Visual Dashboards**:
    - **Daily**: Quick glance at current status.
    - **Weekly/Monthly**: Trend lines (moods) and consistency charts (habits).
4.  **Gamification**:
    - **Points/XP**: Earned per log.
    - **Badges**: Milestones (e.g., "7-Day Streak").
    - **Streaks**: Visual daily streak counter.
5.  **Reminders**: customizable daily notifications.
6.  **Privacy Controls**: Granular data visibility settings.

## Screen List
1.  **Splash / Auth**: Dynamic onboarding -> Login/Signup.
2.  **Main Shell**: Bottom Navigation container handling routing.
3.  **Home Dashboard**: Daily summary, active streaks, "Quick Log" CTA.
4.  **Logging Screen**: 30-second entry form (Activity + Mood + Habits).
5.  **Insights Screen**: Weekly/Monthly visual summaries.
6.  **Achievements**: View badges, points, and current level.
7.  **Profile / Settings**: Privacy toggles and notification preferences.

## Navigation Map
The app uses a bottom tab bar navigation structure:
- **🏠 Home**: Dashboard + Quick Actions
- **📊 Insights**: Historical Trends
- **➕ Add**: Central Floating Action Button (opens Logging Modal)
- **🏆 Awards**: Achievements & Gamification
- **👤 Profile**: Settings & Account

## Folder Structure
The project follows a feature-first architecture for scalability:

```text
lib/
├── core/                  # Core functionality shared across features
│   ├── constants/         # App strings, API keys, etc.
│   ├── theme/             # AppTheme (Colors, Typography)
│   ├── utils/             # Helper functions (Time, Formatters)
│   └── widgets/           # Global reusable widgets (Buttons, Cards)
├── features/              # Feature-specific code
│   ├── auth/              # Authentication logic & screens
│   ├── dashboard/         # Home screen UI & logic
│   ├── logging/           # The specialized logging flow
│   ├── insights/          # Charts and analysis
│   ├── gamification/      # Points, badges, streaks logic
│   └── settings/          # User preferences
├── services/              # External integrations
│   ├── firebase_service.dart
│   ├── notification_service.dart
│   └── storage_service.dart
└── main.dart              # Entry point & app configuration
```

## Technologies
- **Frontend**: Flutter
- **Backend**: Firebase (Auth, Firestore)
- **State Management**: Provider
- **Charts**: fl_chart
- **Local Storage**: shared_preferences
