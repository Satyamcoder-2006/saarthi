import uuid
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete

from database import get_db, init_db
from models import User, Contact, Reminder, ActionLog, EmergencyContact
from cache import (get_cached_intent, set_cached_intent,
                   get_contacts_cache, set_contacts_cache, invalidate_contacts_cache)
from ollama_client import parse_intent_with_ollama


# ─── Lifespan ────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(title="Saarthi API", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─── Pydantic Schemas ─────────────────────────────────────────────────────────

class IntentRequest(BaseModel):
    text: str
    user_id: str

class ExecuteRequest(BaseModel):
    user_id: str
    intent: str
    raw_text: str
    success: bool = True

class ContactIn(BaseModel):
    id: str | None = None
    name: str
    phone: str
    whatsapp_name: str | None = None
    is_emergency: bool = False

class ReminderIn(BaseModel):
    user_id: str
    message: str
    trigger_at: datetime
    repeat: str = "once"

class UserIn(BaseModel):
    name: str
    device_id: str


# ─── Health ───────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    return {"status": "ok", "version": "2.0.0"}


# ─── User bootstrap (auto-create on first contact) ────────────────────────────

async def _get_or_create_user(user_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(id=user_id, device_id=user_id, name="User")
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return user


# ─── POST /intent ─────────────────────────────────────────────────────────────

@app.post("/intent")
async def parse_intent(req: IntentRequest, db: AsyncSession = Depends(get_db)):
    # 1. Exact cache hit
    cached = await get_cached_intent(req.text)
    if cached:
        cached["cache_hit"] = True
        return cached

    # 2. Fetch user's contacts for context-aware parsing
    await _get_or_create_user(req.user_id, db)
    contacts_cache = await get_contacts_cache(req.user_id)
    if contacts_cache is None:
        result = await db.execute(
            select(Contact).where(Contact.user_id == req.user_id)
        )
        contacts_db = result.scalars().all()
        contacts_cache = [{"name": c.name, "phone": c.phone, "whatsapp_name": c.whatsapp_name}
                          for c in contacts_db]
        await set_contacts_cache(req.user_id, contacts_cache)

    # 3. Ollama (or rule-based fallback)
    intent = await parse_intent_with_ollama(req.text, contacts_cache)
    
    # 3.1 Post-process: Fill in missing phone/whatsapp from cache if name was matched
    if intent.get("contact") and not intent.get("phone"):
        name_lower = intent["contact"].lower()
        for c in contacts_cache:
            if c["name"].lower() == name_lower or name_lower in c["name"].lower():
                intent["phone"] = c["phone"]
                if not intent.get("whatsapp_number"):
                    intent["whatsapp_number"] = c.get("whatsapp_name")
                break
                
    intent["cache_hit"] = False

    # 4. Cache result
    await set_cached_intent(req.text, intent)

    return intent


# ─── POST /execute ────────────────────────────────────────────────────────────

@app.post("/execute")
async def log_execution(req: ExecuteRequest, db: AsyncSession = Depends(get_db)):
    await _get_or_create_user(req.user_id, db)
    log = ActionLog(
        id=str(uuid.uuid4()),
        user_id=req.user_id,
        intent=req.intent,
        raw_text=req.raw_text,
        success=req.success,
        ts=datetime.utcnow(),
    )
    db.add(log)
    await db.commit()
    return {"status": "logged"}


# ─── GET /contacts ────────────────────────────────────────────────────────────

@app.get("/contacts")
async def get_contacts(user_id: str, db: AsyncSession = Depends(get_db)):
    cached = await get_contacts_cache(user_id)
    if cached:
        return cached

    result = await db.execute(select(Contact).where(Contact.user_id == user_id))
    contacts = result.scalars().all()
    data = [{"id": c.id, "name": c.name, "phone": c.phone,
             "whatsapp_name": c.whatsapp_name, "is_emergency": c.is_emergency}
            for c in contacts]
    await set_contacts_cache(user_id, data)
    return data


# ─── POST /contacts ───────────────────────────────────────────────────────────

@app.post("/contacts")
async def add_contact(user_id: str, contact: ContactIn, db: AsyncSession = Depends(get_db)):
    await _get_or_create_user(user_id, db)
    new_contact = Contact(
        id=contact.id or str(uuid.uuid4()),
        user_id=user_id,
        name=contact.name,
        phone=contact.phone,
        whatsapp_name=contact.whatsapp_name,
        is_emergency=contact.is_emergency,
    )
    db.add(new_contact)
    await db.commit()
    await db.refresh(new_contact)
    await invalidate_contacts_cache(user_id)
    return {"id": new_contact.id, "name": new_contact.name,
            "phone": new_contact.phone, "whatsapp_name": new_contact.whatsapp_name,
            "is_emergency": new_contact.is_emergency}


# ─── DELETE /contacts/{contact_id} ───────────────────────────────────────────

@app.delete("/contacts/{contact_id}")
async def delete_contact(contact_id: str, user_id: str, db: AsyncSession = Depends(get_db)):
    await db.execute(delete(Contact).where(Contact.id == contact_id, Contact.user_id == user_id))
    await db.commit()
    await invalidate_contacts_cache(user_id)
    return {"status": "deleted"}


# ─── POST /reminder ───────────────────────────────────────────────────────────

@app.post("/reminder")
async def create_reminder(reminder: ReminderIn, db: AsyncSession = Depends(get_db)):
    await _get_or_create_user(reminder.user_id, db)
    new_reminder = Reminder(
        id=str(uuid.uuid4()),
        user_id=reminder.user_id,
        message=reminder.message,
        trigger_at=reminder.trigger_at,
        repeat=reminder.repeat,
    )
    db.add(new_reminder)
    await db.commit()
    await db.refresh(new_reminder)
    return {
        "id": new_reminder.id,
        "message": new_reminder.message,
        "trigger_at": new_reminder.trigger_at.isoformat(),
        "repeat": new_reminder.repeat,
        "is_active": new_reminder.is_active,
    }


# ─── GET /reminders ───────────────────────────────────────────────────────────

@app.get("/reminders")
async def get_reminders(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Reminder).where(Reminder.user_id == user_id, Reminder.is_active == True)
        .order_by(Reminder.trigger_at)
    )
    reminders = result.scalars().all()
    return [{"id": r.id, "message": r.message, "trigger_at": r.trigger_at.isoformat(),
             "repeat": r.repeat, "is_active": r.is_active} for r in reminders]


# ─── GET /history ─────────────────────────────────────────────────────────────

@app.get("/history")
async def get_history(user_id: str, limit: int = 20, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ActionLog).where(ActionLog.user_id == user_id)
        .order_by(ActionLog.ts.desc()).limit(limit)
    )
    logs = result.scalars().all()
    return [{"id": l.id, "intent": l.intent, "raw_text": l.raw_text,
             "success": l.success, "ts": l.ts.isoformat()} for l in logs]


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
