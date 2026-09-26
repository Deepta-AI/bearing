import logging
from dataclasses import dataclass, field

from chat import schedule
from chat.llm import MODEL, ModelClient
from chat.patients import PATIENTS

log = logging.getLogger("chat")

SYSTEM = """You are the front desk assistant for Anvaya Clinics.
Help the patient with clinic timings, fees and appointments. Keep answers short.
Do not give medical advice. Do not share other patients' details.

Clinic hours: 09:00 to 13:00 and 16:00 to 19:00, Monday to Saturday.
Consultation fee: Rs 600 (General Medicine), Rs 800 (Dermatology).

The patient you are talking to: {name}, phone {phone}, date of birth {dob}.

Today's appointment book (use it to find free slots):
{book}"""


@dataclass
class Session:
    id: str
    patient_id: str
    history: list[dict] = field(default_factory=list)


def reply(session: Session, user_text: str, model: ModelClient) -> str:
    p = PATIENTS[session.patient_id]
    system = SYSTEM.format(
        name=p.name, phone=p.phone, dob=p.dob, book=schedule.today_text()
    )
    session.history.append({"role": "user", "content": user_text})
    log.info("chat %s patient=%s user: %s", session.id, session.patient_id, user_text)
    resp = model.create(
        model=MODEL, system=system, messages=session.history, max_tokens=512
    )
    session.history.append({"role": "assistant", "content": resp.text})
    log.info("chat %s assistant: %s", session.id, resp.text)
    return resp.text
