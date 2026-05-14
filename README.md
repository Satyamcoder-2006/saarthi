# Saarthi (सारथी) - AI Voice Assistant for Elderly

Saarthi is a production-grade, privacy-focused voice assistant specifically designed for elderly users in India. It simplifies complex smartphone actions into natural voice conversations.

> **Status**: 🛠️ Work in Progress (Productionizing Stage)

---

## 🌟 Key Features

### 🎙️ Intent-Based Voice Control
*   **"Call Ramesh"** - Automatically look up contact and trigger phone dialer.
*   **"WhatsApp daughter"** - Send messages via WhatsApp using voice.
*   **"Navigate to Hospital"** - Open Google Maps with pre-filled destination.
*   **"Play Bhajan"** - Search and play music on YouTube.
*   **"Remind me of medicine"** - Set voice-triggered reminders.

### 🧠 Intelligent Backend (Hybrid Architecture)
*   **Local STT**: Uses **Vosk** on the device for fast, offline speech-to-text.
*   **LLM Processing**: Uses **Ollama (Llama 3)** on the local host to parse complex sentences into structured intents.
*   **Rule-Based Fallback**: Instant processing even when the LLM is slow or offline.
*   **Semantic Caching**: Redis-powered cache for near-instant response to common commands.

### 👴 Elderly-Friendly UX
*   **High-Contrast UI**: Large buttons and readable fonts.
*   **Confirmation Loop**: The app talks back ("Should I call Ravi?") before taking any action, preventing accidental dials.
*   **Aggressive Silence Detection**: No need to "stop" the mic manually; it knows when you've finished talking.

---

## 🏗️ Architecture

```mermaid
graph TD
    A[Flutter App] -->|STT| B[Voice Service]
    B -->|Transcript| C[FastAPI Backend]
    C -->|Query| D{Redis Cache}
    D -->|Miss| E[Ollama LLM]
    E -->|JSON Intent| C
    C -->|Response| A
    A -->|Confirmation| F[Action Executor]
    F -->|System Call| G[Dialer/WhatsApp/Maps]
```

---

## 🚀 Setup & Installation

### 1. Backend (Python/Podman)
Ensure you have Python 3.10+ and Podman (or Docker) installed.

```bash
cd backend
pip install -r requirements.txt
# Start Redis
podman run -d --name saarthi_redis --net host redis:7-alpine
# Start API
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

### 2. Local Intelligence (Ollama)
Install [Ollama](https://ollama.com/) and download the model:
```bash
ollama run llama3
```

### 3. Flutter App
Ensure your phone is in Developer Mode with USB Debugging enabled.

```bash
flutter pub get
flutter run
```

---

## 🗺️ Roadmap
- [x] Vosk Offline STT Integration
- [x] FastAPI Backend with SQLite/Redis
- [x] Intent Parsing via Ollama
- [x] Proactive Android Permission Handling
- [ ] Contact Sync (Address Book -> Backend)
- [ ] Emergency SOS Hardware Trigger
- [ ] Multi-lingual support (Hindi/Hinglish LLM tuning)

---

## 📝 License
Proprietary / Built for User Satisfaction.
