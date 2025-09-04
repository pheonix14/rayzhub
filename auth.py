import hashlib
import os
import time
import json
import base64
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
import database, models, schemas

SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "rayzhub_super_secret_jwt_key_2025")
ALGORITHM = "HS256"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

def hash_password(password: str) -> str:
    salt = b"rayzhub_secure_salt_2025_v2"
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return key.hex()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return hash_password(plain_password) == hashed_password

def create_access_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = int(time.time()) + (24 * 3600) # 24 hour expiry
    header = {"alg": "HS256", "typ": "JWT"}
    
    header_bytes = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip("=")
    payload_bytes = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    signature_base = f"{header_bytes}.{payload_bytes}"
    signature = hashlib.sha256((signature_base + SECRET_KEY).encode()).hexdigest()
    
    return f"{signature_base}.{signature}"

def decode_access_token(token: str) -> dict:
    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("Invalid token format")
        
        header_b64, payload_b64, sig = parts
        signature_base = f"{header_b64}.{payload_b64}"
        expected_sig = hashlib.sha256((signature_base + SECRET_KEY).encode()).hexdigest()
        
        if sig != expected_sig:
            raise ValueError("Invalid signature")
        
        # Add padding back if necessary
        padding = "=" * (4 - len(payload_b64) % 4)
        payload_json = base64.urlsafe_b64decode(payload_b64 + padding).decode()
        payload = json.loads(payload_json)
        
        if payload.get("exp", 0) < time.time():
            raise ValueError("Token expired")
            
        return payload
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)) -> models.User:
    payload = decode_access_token(token)
    email: str = payload.get("sub")
    if email is None:
        raise HTTPException(status_code=401, detail="Invalid authentication token")
    
    user = db.query(models.User).filter(models.User.email == email).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return user
