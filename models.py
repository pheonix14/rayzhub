from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text
import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=True)
    role = Column(String, default="admin")
    is_verified = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class RequestItem(Base):
    __tablename__ = "requests"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=True)
    email = Column(String, nullable=True)
    message = Column(String, index=True)
    photo_path = Column(String, nullable=True)
    request_type = Column(String, default="request")
    amount = Column(String, nullable=True)
    transaction_id = Column(String, nullable=True)
    is_anonymous = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    status = Column(String, default="pending")

class VerificationLog(Base):
    __tablename__ = "verification_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    action = Column(String, nullable=False)
    ip_address = Column(String, nullable=True)
    status = Column(String, default="success")
    details = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class WidgetConfig(Base):
    __tablename__ = "widget_configs"

    id = Column(Integer, primary_key=True, index=True)
    config_key = Column(String, unique=True, index=True, nullable=False)
    config_json = Column(Text, nullable=False)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

class LinkItem(Base):
    __tablename__ = "links"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    target_url = Column(String, nullable=False)
    short_code = Column(String, unique=True, index=True, nullable=False)
    clicks = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
