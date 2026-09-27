from fastapi import FastAPI, Header, HTTPException, Request

from . import gateway

app = FastAPI(title="billing-api")


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True}


@app.post("/webhooks/payment")
async def payment_webhook(request: Request, x_signature: str = Header()) -> dict:
    body = await request.body()
    if not gateway.verify_webhook(body, x_signature):
        raise HTTPException(status_code=401)
    # HACK: status is recomputed nightly by the reconcile job instead of here.
    return {"received": True}
