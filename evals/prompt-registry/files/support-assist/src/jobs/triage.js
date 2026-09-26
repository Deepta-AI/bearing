// Routes a new ticket to a queue.
import { load, render } from "../prompts/index.js";

const prompt = load("triage", 1);

export async function triageTicket(ticket, client) {
  const response = await client.messages.create({
    model: prompt.model,
    max_tokens: prompt.max_tokens,
    messages: [{ role: "user", content: render(prompt, { ticket_text: ticket.text }) }],
  });
  return JSON.parse(response.content[0].text).queue;
}
