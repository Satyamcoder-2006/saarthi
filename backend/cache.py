import json
import hashlib
import os
import redis.asyncio as aioredis

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
SIMILARITY_THRESHOLD = 0.92

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis | None:
    global _redis
    if _redis is None:
        try:
            _redis = await aioredis.from_url(REDIS_URL, decode_responses=True)
            await _redis.ping()
        except Exception:
            _redis = None  # Redis unavailable — graceful fallback
    return _redis


def _hash_key(text: str) -> str:
    return "intent:" + hashlib.sha256(text.strip().lower().encode()).hexdigest()


async def get_cached_intent(transcript: str) -> dict | None:
    """Exact cache lookup by transcript hash."""
    r = await get_redis()
    if r is None:
        return None
    try:
        key = _hash_key(transcript)
        raw = await r.get(key)
        return json.loads(raw) if raw else None
    except Exception:
        return None


async def set_cached_intent(transcript: str, intent: dict, ttl: int = 3600):
    """Cache intent response for 1 hour."""
    r = await get_redis()
    if r is None:
        return
    try:
        key = _hash_key(transcript)
        await r.setex(key, ttl, json.dumps(intent))
    except Exception:
        pass


async def get_contacts_cache(user_id: str) -> list | None:
    """Contact list cached for 24 hours."""
    r = await get_redis()
    if r is None:
        return None
    try:
        raw = await r.get(f"contacts:{user_id}")
        return json.loads(raw) if raw else None
    except Exception:
        return None


async def set_contacts_cache(user_id: str, contacts: list, ttl: int = 86400):
    r = await get_redis()
    if r is None:
        return
    try:
        await r.setex(f"contacts:{user_id}", ttl, json.dumps(contacts))
    except Exception:
        pass


async def invalidate_contacts_cache(user_id: str):
    r = await get_redis()
    if r is None:
        return
    try:
        await r.delete(f"contacts:{user_id}")
    except Exception:
        pass
