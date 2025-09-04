from sqlalchemy import create_engine, inspect, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

SQLALCHEMY_DATABASE_URL = "sqlite:///./requests.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def auto_migrate():
    inspector = inspect(engine)
    if "requests" in inspector.get_table_names():
        columns = [c["name"] for c in inspector.get_columns("requests")]
        with engine.connect() as conn:
            if "name" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN name VARCHAR"))
            if "email" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN email VARCHAR"))
            if "request_type" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN request_type VARCHAR DEFAULT 'request'"))
            if "amount" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN amount VARCHAR"))
            if "transaction_id" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN transaction_id VARCHAR"))
            if "is_anonymous" not in columns:
                conn.execute(text("ALTER TABLE requests ADD COLUMN is_anonymous BOOLEAN DEFAULT 0"))
            conn.commit()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
