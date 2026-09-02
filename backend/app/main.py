from fastapi import FastAPI, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.core.database import get_db

app = FastAPI(title="MSU ANPR Platform API")

@app.get("/")
def root():
    return {"status": "ok", "service": "MSU ANPR Platform API"}

@app.get("/health/db")
def health_db(db: Session = Depends(get_db)):
    result = db.execute(text("SELECT count(*) FROM information_schema.tables WHERE table_schema='public'"))
    table_count = result.scalar()
    return {"status": "connected", "tables_found": table_count}