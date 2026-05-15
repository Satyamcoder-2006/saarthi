import httpx
import json
import os

OLLAMA_BASE = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3")

SYSTEM_PROMPT = """You are a voice assistant for elderly Indian users. Parse voice commands into structured JSON.

IMPORTANT: Elderly Indian users often have heavy accents. The voice transcript might contain phonetical errors (e.g., "call papa" might come as "karl pooper" or "call popa"). Use context and common sense to map these to the correct intent.

Given a voice transcript, return ONLY valid JSON with this exact structure:
{
  "intent": "<intent_type>",
  "confidence": <0.0-1.0>,
  "contact": "<name or null>",
  "phone": "<phone number or null>",
  "message": "<message text or null>",
  "destination": "<place name or null>",
  "appName": "<app name or null>",
  "query": "<search query or null>",
  "reminderTime": "<ISO datetime string or null>",
  "reminderMessage": "<reminder text or null>"
}

Valid intent types:
- call_contact: user wants to call someone ("call ravi", "dial my son")
- send_whatsapp: user wants to send WhatsApp message ("whatsapp ravi", "send message to son on whatsapp")
- send_sms: user wants to send SMS ("send message to", "text")
- navigate_to: user wants directions ("take me to", "go to", "navigate to", "how do I get to")
- open_app: user wants to open an app ("open youtube", "start camera")
- play_music: user wants music ("play", "song", "music")
- set_reminder: user wants a reminder ("remind me", "set alarm", "alert me")
- emergency_call: user is in distress ("help", "emergency", "I fell", "not feeling well")
- unknown: cannot be determined

NICKNAME MAPPING:
If the user mentions "Papa", "Mummy", "Son", "Daughter", "Bhai", "Did", etc., and they aren't in the contacts list, still return the name in the "contact" field.

Return ONLY the JSON object, no explanation."""


async def parse_intent_with_ollama(transcript: str, contacts: list[dict]) -> dict:
    """
    Call Ollama to parse voice transcript into structured intent.
    Falls back to rule-based parsing if Ollama is unavailable.
    """
    # Build contact context
    contact_context = ""
    if contacts:
        names = ", ".join([c["name"] for c in contacts[:20]])
        contact_context = f"\n\nKnown contacts: {names}\nIf the user mentions a contact name, match it to the known contacts list."

    user_prompt = f'Voice transcript: "{transcript}"{contact_context}'

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{OLLAMA_BASE}/api/generate",
                json={
                    "model": OLLAMA_MODEL,
                    "prompt": f"{SYSTEM_PROMPT}\n\n{user_prompt}",
                    "stream": False,
                    "options": {"temperature": 0.1},
                },
            )
            if response.status_code == 200:
                raw = response.json().get("response", "")
                # Extract JSON from response
                start = raw.find("{")
                end = raw.rfind("}") + 1
                if start >= 0 and end > start:
                    return json.loads(raw[start:end])
    except Exception as e:
        print(f"Ollama unavailable: {e}. Falling back to rule-based parser.")

    return _rule_based_parse(transcript, contacts)


def _rule_based_parse(transcript: str, contacts: list[dict]) -> dict:
    """
    Fast, deterministic rule-based intent parser.
    Used as fallback when Ollama is unavailable.
    """
    text = transcript.lower().strip()
    base = {"confidence": 0.0, "contact": None, "phone": None, "message": None,
            "destination": None, "appName": None, "query": None,
            "reminderTime": None, "reminderMessage": None}

    # Emergency — highest priority
    emergency_keywords = ["help", "emergency", "fell", "chest pain", "not feeling well", 
                         "accident", "ambulance", "hospital"]
    if any(kw in text for kw in emergency_keywords):
        return {**base, "intent": "emergency_call", "confidence": 0.95}

    # Match contact name from known contacts
    matched_contact = None
    matched_phone = None
    for c in contacts:
        if c["name"].lower() in text:
            matched_contact = c["name"]
            matched_phone = c.get("phone")
            break

    # Call intent
    if any(kw in text for kw in ["call", "dial", "phone", "ring"]):
        name = matched_contact or _extract_name_after_keyword(text, ["call", "dial", "phone", "ring"])
        return {**base, "intent": "call_contact", "confidence": 0.88,
                "contact": name, "phone": matched_phone}

    # WhatsApp intent
    if "whatsapp" in text or ("message" in text and "whatsapp" in text):
        name = matched_contact or _extract_name_after_keyword(text, ["whatsapp", "to"])
        msg = _extract_message(text)
        return {**base, "intent": "send_whatsapp", "confidence": 0.88,
                "contact": name, "phone": matched_phone, "message": msg or "Hello!"}

    # SMS intent
    if any(kw in text for kw in ["sms", "text", "message"]):
        name = matched_contact or _extract_name_after_keyword(text, ["to", "message"])
        msg = _extract_message(text)
        return {**base, "intent": "send_sms", "confidence": 0.8,
                "contact": name, "phone": matched_phone, "message": msg}

    # Navigation intent
    if any(kw in text for kw in ["go to", "navigate", "take me to", "directions", "how do i get"]):
        dest = _extract_destination(text)
        return {**base, "intent": "navigate_to", "confidence": 0.85, "destination": dest}

    # Reminder intent
    if any(kw in text for kw in ["remind", "reminder", "alarm", "alert"]):
        return {**base, "intent": "set_reminder", "confidence": 0.82,
                "reminderMessage": text}

    # Music intent
    if any(kw in text for kw in ["play", "song", "music", "gana"]):
        query = text.replace("play", "").replace("song", "").replace("music", "").strip()
        return {**base, "intent": "play_music", "confidence": 0.8, "query": query}

    # Open app
    if any(kw in text for kw in ["open", "start", "launch"]):
        app = _extract_name_after_keyword(text, ["open", "start", "launch"])
        return {**base, "intent": "open_app", "confidence": 0.75, "appName": app}

    return {**base, "intent": "unknown", "confidence": 0.0}


def _extract_name_after_keyword(text: str, keywords: list[str]) -> str | None:
    for kw in keywords:
        if kw in text:
            parts = text.split(kw, 1)
            if len(parts) > 1:
                name = parts[1].strip().split()[0] if parts[1].strip() else None
                return name.title() if name else None
    return None


def _extract_message(text: str) -> str | None:
    for sep in ["saying", "say", "that", "message"]:
        if sep in text:
            parts = text.split(sep, 1)
            if len(parts) > 1 and parts[1].strip():
                return parts[1].strip().capitalize()
    return None


def _extract_destination(text: str) -> str | None:
    for kw in ["go to", "navigate to", "take me to", "directions to"]:
        if kw in text:
            dest = text.split(kw, 1)[1].strip()
            return dest.title() if dest else None
    return None
