import logging

from bot import tools
from bot.llm import MODEL, ModelClient
from bot.session import Session

log = logging.getLogger("bot.loop")

SYSTEM = (
    "You are the shop's help assistant. Answer briefly. Use get_faq for delivery, returns and payment "
    "questions. If you cannot help, call escalate_to_human."
)


def respond(session: Session, user_text: str, model: ModelClient) -> str:
    session.messages.append({"role": "user", "content": user_text})
    while True:
        resp = model.create(model=MODEL, system=SYSTEM, messages=session.messages, tools=tools.SCHEMAS, max_tokens=1024)
        log.info("model response for %s: %s", session.conversation_id, resp.content)
        session.messages.append({"role": "assistant", "content": resp.content})
        if resp.stop_reason == "tool_use":
            results = []
            for block in resp.content:
                if block["type"] == "tool_use":
                    fn = getattr(tools, block["name"])
                    out = fn(**block["input"])
                    results.append({"type": "tool_result", "tool_use_id": block["id"], "content": tools.dumps(out)})
            session.messages.append({"role": "user", "content": results})
            continue
        return "".join(b["text"] for b in resp.content if b["type"] == "text")
