// Agent chat helper: the agent asks a question about the open ticket and
// gets a suggested answer.

export async function chatHandler(req, client) {
  const { user, ticket, question } = req.body;
  const plan = user.plan ?? "standard";

  const response = await client.messages.create({
    model: "claude-sonnet-5",
    max_tokens: 800,
    system: `You are Harbourline's support copilot helping ${user.displayName}, a ${plan} tier support agent.
Answer the agent's question about the ticket below using Harbourline policy: refunds within 30 days of delivery, free returns on orders over 999 rupees, replacements for damaged items without a return.
Never promise compensation beyond policy. If you are not sure, tell the agent to check with a team lead.
Ticket:
${ticket.text}`,
    messages: [{ role: "user", content: question }],
  });
  return { answer: response.content[0].text };
}
