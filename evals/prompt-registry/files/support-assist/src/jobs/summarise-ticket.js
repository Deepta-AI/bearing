// Summarises a ticket thread when it is reassigned to another agent.
import { load, render } from "../prompts/index.js";

const prompt = load("summarise", 2);

export async function summariseTicket(ticket, agentNote, client) {
  const text = render(prompt, { ticket_text: ticket.thread, customer_note: agentNote });
  const response = await client.messages.create({
    // haiku is cheaper and fast enough for summaries
    model: "claude-haiku-4-5",
    max_tokens: prompt.max_tokens,
    messages: [{ role: "user", content: text }],
  });
  return response.content[0].text;
}
