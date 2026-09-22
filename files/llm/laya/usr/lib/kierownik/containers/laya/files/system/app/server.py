"""Laya English-only decision microservice (convaiinnovations/laya)."""
# ponytail: direct laya.load, no Router — English-only per scope; add Router when multilingual needed.

import os

os.environ.setdefault("USE_TF", "0")

from fastapi import FastAPI, HTTPException

import laya

MODEL_ID = os.environ.get("LAYA_MODEL", "convaiinnovations/laya")

app = FastAPI(title="laya-decision", version="1.0.0")
agent = laya.load(MODEL_ID)


@app.get("/")
def root():
    return {"service": "laya-decision", "model": MODEL_ID, "endpoints": ["/health", "/predict"]}


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_ID}


@app.post("/predict")
def predict(payload: dict):
    state = payload.get("state")
    questions = payload.get("questions")
    if not isinstance(state, dict) or not isinstance(questions, dict):
        raise HTTPException(status_code=400, detail="body needs {state: {}, questions: {}}")
    try:
        return agent.predict(state, questions)
    except Exception as e:  # noqa: BLE001 — surface model errors as 500
        raise HTTPException(status_code=500, detail=str(e)) from e
