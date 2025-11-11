# 🚔 Nampol E-Policing System

<div align="center">

**Empowering Namibian Law Enforcement with Modern Digital Tools**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange?logo=firebase)](https://firebase.google.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

*A modern Flutter mobile application designed to empower Namibian police officers with real-time digital tools for efficient field operations, incident management, and secure communication — even in offline environments.*

[Features](#-features) • [Installation](#-installation) • [Documentation](#-documentation) • [Contributing](#-contributing) • [License](#-license)

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Installation](#-installation)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Usage](#-usage)
- [Security](#-security)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [License](#-license)
- [Contact](#-contact)
- [Acknowledgments](#-acknowledgments)

---

## 🛰️ Overview

**Nampol E-Policing** is an innovative mobile solution that enables law enforcement officers to **digitally record, monitor, and communicate** during daily operations. The prototype demonstrates how smart policing can improve **response time**, **incident reporting accuracy**, and **situational awareness** using cloud and offline-first technology.

### Why Nampol E-Policing?

- 🌍 **Offline-First Design** - Works in remote areas with limited connectivity
- ⚡ **Real-Time Coordination** - Instant communication between field officers and command
- 📊 **Data-Driven Insights** - Better resource allocation and operational efficiency
- 🔐 **Secure & Compliant** - Built with law enforcement security standards in mind
- 🇳🇦 **Made for Namibia** - Designed specifically for Namibian law enforcement needs

---

## ✨ Features

### Core Functionality

| Feature | Description | Status |
|---------|-------------|--------|
| 📝 **Incident Reporting** | Create, edit, and submit incident reports from the field with offline sync | ✅ Active |
| 📡 **Offline Mode** | Seamless operation in low/no connectivity zones with local storage | ✅ Active |
| 👮 **Patrol Mode** | Track patrol routes and mark checkpoints for accountability | ✅ Active |
| 📍 **Real-Time Location** | Live GPS tracking with Google Maps integration | ✅ Active |
| 🔒 **Secure Communication** | Encrypted in-app messaging for officer coordination | ✅ Active |
| 📷 **Evidence Capture** | Attach photos, videos, and voice notes to reports | ✅ Active |
| 🚨 **Backup Requests** | One-tap distress alerts to nearby units and command | ✅ Active |
| 🧾 **Case History** | Access past reports and logs, even offline | ✅ Active |
| 🔔 **Push Notifications** | Real-time alerts for assignments and updates | ✅ Active |

### Upcoming Features

| Feature | Description | Status |
|---------|-------------|--------|
| 🗺️ **Geofencing** | Automatic alerts for patrol zone boundaries | 🔄 Planned |
| 📊 **Analytics Dashboard** | Insights on response times and patrol coverage | 🔄 Planned |
| 🌐 **Multi-Language** | Support for English and Oshiwambo | 🔄 Planned |
| 👨‍💼 **Admin Portal** | Web-based command center dashboard | 🔄 Planned |

---

## 🛠️ Tech Stack

### Mobile Application

```
Frontend:     Flutter (Dart)
Backend:      Firebase (Firestore, Auth, Cloud Messaging, Storage)
Maps:         Google Maps Platform
Auth:         Firebase Authentication
State:        Provider (Riverpod migration planned)
Environment:  flutter_dotenv
Platform:     Android (iOS planned)
```

### Architecture

- **MVVM Pattern** - Clean separation of concerns
- **Offline-First** - Local data persistence with Firebase sync
- **Modular Design** - Scalable and maintainable codebase

---

## 📦 Installation

### Prerequisites

- Flutter SDK (3.0 or higher)
- Android Studio / VS Code with Flutter extensions
- Firebase account
- Google Maps API key

### Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/Blackjuiceplug/nampol-e-policing-prototype.git
cd nampol_e-policing_prototype/nampol_app

# 2. Install dependencies
flutter pub get

# 3. Create environment file
cp .env.example .env
# Edit .env and add your Google Maps API key

# 4. Run the app
flutter run
```

### Detailed Setup

<details>
<summary>Click to expand detailed installation steps</summary>

#### 1. Flutter Setup

```bash
# Verify Flutter installation
flutter doctor

# If needed, install Flutter from:
# https://docs.flutter.dev/get-started/install
```

#### 2. Firebase Configuration

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Firestore, Authentication, Storage, and Cloud Messaging
3. Download `google-services.json` for Android
4. Place it in `android/app/`

#### 3. Google Maps Setup

1. Get API key from [Google Cloud Console](https://console.cloud.google.com)
2. Enable Maps SDK for Android
3. Add key to `.env` file

#### 4. Build and Run

```bash
# Debug build
flutter run

# Release build
flutter build apk --release
```

</details>

---

## 🧱 Project Structure

```
nampol_e-policing_prototype/
├── nampol_app/                 # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── screens/           # UI screens
│   │   │   ├── home/
│   │   │   ├── incident/
│   │   │   ├── patrol/
│   │   │   └── profile/
│   │   ├── widgets/           # Reusable components
│   │   ├── services/          # Business logic
│   │   │   ├── auth_service.dart
│   │   │   ├── firestore_service.dart
│   │   │   └── location_service.dart
│   │   ├── models/            # Data models
│   │   └── utils/             # Helper functions
│   ├── assets/                # Images, fonts, etc.
│   ├── android/               # Android-specific files
│   ├── ios/                   # iOS-specific files
│   ├── .env.example           # Environment template
│   ├── .gitignore
│   ├── pubspec.yaml           # Dependencies
│   └── README.md
├── nampol_admin/              # Future web admin panel
├── docs/                      # Documentation
├── LICENSE                    # MIT License
└── README.md                  # This file
```

---

## ⚙️ Configuration

### Environment Variables

Create a `.env` file in `nampol_app/`:

```env
# Google Maps
GOOGLE_MAPS_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXX

# Firebase (optional - already in google-services.json)
FIREBASE_API_KEY=your_firebase_api_key
FIREBASE_PROJECT_ID=your_project_id

# App Configuration
APP_ENV=development
DEBUG_MODE=true
```

**⚠️ Security Note:** Never commit `.env` to version control. It's already in `.gitignore`.

---

## 🚀 Usage

### For Officers

1. **Login** with your credentials
2. **Start Patrol** to track your route
3. **Report Incidents** with photos and location
4. **Request Backup** in emergencies
5. **View Case History** anytime, anywhere

### For Administrators

1. Monitor active patrols on map
2. Review submitted incident reports
3. Coordinate officer deployment
4. Analyze operational data

---

## 🛡️ Security

- 🔐 **End-to-End Encryption** - Secure data transmission
- 🗄️ **Encrypted Storage** - Protected local data
- 🔑 **Firebase Auth** - Secure authentication
- 🚫 **No Plaintext Secrets** - Environment-based configuration
- 📱 **Biometric Support** - Fingerprint/Face ID (planned)
- 🔒 **Role-Based Access** - Granular permissions (planned)

### Reporting Security Issues

Please report security vulnerabilities to: **mundjelefelix@gmail.com**

---

## 🗓️ Roadmap

### Phase 1: Core Features (Current)
- [x] Incident reporting with offline support
- [x] Patrol tracking and checkpoints
- [x] Real-time location sharing
- [x] Evidence attachment (photo/video/audio)
- [x] Emergency backup requests

### Phase 2: Enhanced Features 
- [X] Web admin dashboard
- [ ] Advanced analytics and reporting
- [ ] Multi-language support (English, Oshiwambo)
- [ ] Geofencing and zone management
- [ ] iOS application

### Phase 3: Integration 
- [ ] National incident database integration
- [ ] Interoperability with existing systems
- [ ] Advanced role-based access control
- [ ] API for third-party integrations
- [ ] Biometric authentication

### Phase 4: Scale 
- [ ] Nationwide deployment
- [ ] AI-powered incident prediction
- [ ] Body camera integration
- [ ] Vehicle tracking integration

---

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, improving documentation, or proposing new features, your help is appreciated.

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Contribution Guidelines

- Follow the existing code style
- Write clear commit messages
- Add tests for new features
- Update documentation as needed
- Ensure all tests pass before submitting

### Development Setup

```bash
# Install development dependencies
flutter pub get

# Run tests
flutter test

# Check code quality
flutter analyze

# Format code
flutter format .
```

---

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### What this means:
- ✅ Commercial use
- ✅ Modification
- ✅ Distribution
- ✅ Private use
- ⚠️ Liability and warranty disclaimers apply

---

## 📧 Contact

**Developer:** Felix "Blackjuiceplug" Munjele  
**Email:** mundjelefelix@gmail.com  
**Location:** Windhoek, Namibia 🇳🇦  
**GitHub:** [@Blackjuiceplug](https://github.com/Blackjuiceplug)

### Connect With Us

- 🐛 [Report Issues](https://github.com/Blackjuiceplug/nampol-e-policing-prototype/issues)
- 💡 [Request Features](https://github.com/Blackjuiceplug/nampol-e-policing-prototype/issues/new)
- 📖 [Documentation](https://github.com/Blackjuiceplug/nampol-e-policing-prototype/wiki)

---

## 🙏 Acknowledgments

- **Namibian Police Force** - For inspiration and operational insights
- **Flutter Community** - For excellent documentation and support
- **Firebase Team** - For robust backend infrastructure
- **Contributors** - Everyone who has contributed to this project

---

## 📊 Project Stats

![GitHub stars](https://img.shields.io/github/stars/Blackjuiceplug/nampol-e-policing-prototype?style=social)
![GitHub forks](https://img.shields.io/github/forks/Blackjuiceplug/nampol-e-policing-prototype?style=social)
![GitHub issues](https://img.shields.io/github/issues/Blackjuiceplug/nampol-e-policing-prototype)
![GitHub pull requests](https://img.shields.io/github/issues-pr/Blackjuiceplug/nampol-e-policing-prototype)

---

<div align="center">

**Made with ❤️ in Namibia 🇳🇦**

*Building smarter, safer communities through technology*

[⬆ Back to Top](#-nampol-e-policing-system)

</div>