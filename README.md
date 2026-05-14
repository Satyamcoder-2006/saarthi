# Saarthi — Voice-First Assistant for Elderly Indian Users

**Saarthi** is a production-ready Flutter Android application designed specifically to empower elderly users through a voice-first interface. It acts as a bridge between the user and their smartphone, simplifying complex tasks like calling contacts, sending messages, setting reminders, and navigating through voice commands.

---

## 🌟 Key Features

- **Voice-First Interface**: Powered by **Vosk STT**, the app listens and interprets commands locally on the device.
- **AI Intent Parsing**: Communicates with a local FastAPI backend to parse user intents with high precision.
- **Senior-Friendly Design**: Uses large fonts (min 16sp, default 22sp), high-contrast colors, and a clean, bold layout.
- **Emergency Integration**: One-tap emergency call button and voice-activated emergency mode that alerts contacts with the user's GPS location.
- **Local Intelligence**: Uses **Hive** for ultra-fast local storage and offline access to contacts and history.
- **Multi-Lingual Support**: Initial support for English (India), with placeholders and infrastructure for Hindi, Tamil, and Telugu.
- **Assistive TTS**: Integrated **Flutter TTS** that speaks confirmations and errors in a clear, slower-than-normal voice suited for elderly users.

---

## 🛠️ Project Architecture

The app follows a robust **MVVM (Model-View-ViewModel)** architecture using the **Provider** pattern for state management.

- **`lib/core`**: Contains constants, models, services (API, TTS, Voice, Storage), and utilities (Action Executor, Fuzzy Matcher).
- **`lib/features`**: Feature-based organization containing:
  - **Onboarding**: Splash and dynamic Backend Setup screens.
  - **Home**: The central command hub with an animated mic interface.
  - **Listening**: Real-time voice overlay with partial result streaming.
  - **Contacts**: Fuzzy-searchable contact list with emergency and WhatsApp tagging.
  - **Reminders**: Local notification management for medicine and tasks.
  - **History**: Grouped action logs of past interactions.
  - **Settings**: Comprehensive control over text size, voice speed, and connectivity.
- **`lib/shared`**: Reusable widgets like `SaarthiBottomNav` and `ActionCard`.

---

## 📊 Completion Status (Phase 1)

| Feature | Status | Implementation Details |
| :--- | :--- | :--- |
| **Core UI / Theme** | ✅ 100% | High-contrast design, Poppins/Noto Sans typography. |
| **State Management** | ✅ 100% | MultiProvider setup for all features. |
| **API Integration** | ✅ 100% | Dio-based connectivity to local FastAPI backend. |
| **Voice STT (Vosk)** | ✅ 100% | Real-time listening with model auto-download (50MB). |
| **TTS Implementation** | ✅ 100% | Multi-lingual speech synthesis with speed control. |
| **Local Storage** | ✅ 100% | Hive boxes for Contacts, Reminders, and History. |
| **Action Execution** | ✅ 100% | Calling, SMS, WhatsApp, Maps, and App Launching. |
| **Onboarding Flow** | ✅ 100% | WiFi connectivity test and backend configuration. |
| **Emergency Mode** | ✅ 100% | FAB-based alerts and SMS location sharing. |
| **Notification System** | 🏗️ 80% | Local notification logic structured, requires plugin config. |

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK**: Ensure you have the latest stable version of Flutter installed.
2. **Local Backend**: This app requires the **Saarthi FastAPI Backend** running on the same WiFi network.
3. **Android Device**: A physical Android device is recommended for testing microphone and calling features.

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Satyamcoder-2006/saarthi.git
   cd saarthi
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Hive Adapters**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Run the app**:
   ```bash
   flutter run
   ```

---

## 📝 Configuration

On the first launch, the app will ask for the **Laptop IP Address**. 
- Open your laptop terminal and run `ipconfig` (Windows) or `ifconfig` (Mac/Linux).
- Enter the IPv4 address shown into the app.
- Ensure the backend port (default: 8000) matches your FastAPI configuration.

---

## ⚖️ License

This project is licensed under the MIT License.

*Built with ❤️ for a more inclusive digital future.*
