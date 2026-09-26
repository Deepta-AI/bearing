// Model client interface. Production passes an SDK client with
// messages.create(); tests pass a fake with the same shape.

export function fakeClient(reply = "ok") {
  const calls = [];
  return {
    calls,
    messages: {
      async create(req) {
        calls.push(req);
        return { content: [{ type: "text", text: reply }], model: req.model, stop_reason: "end_turn" };
      },
    },
  };
}
