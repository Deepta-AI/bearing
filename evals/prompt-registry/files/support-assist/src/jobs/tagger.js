// Nightly job: adds up to three tags to tickets closed today.

const TAG_PROMPT =
  "You tag closed customer support tickets for Harbourline so that the insights team can count recurring problems. Choose up to three tags from this list and no others: damaged_item, late_delivery, wrong_item, refund_request, return_request, payment_failed, account_access, coupon_issue, praise. Reply with the tags separated by commas, lowercase, and nothing else. If none fits, reply with none.";

export async function tagTicket(ticket, client) {
  const response = await client.messages.create({
    model: "claude-haiku-4-5",
    max_tokens: 30,
    system: TAG_PROMPT,
    messages: [{ role: "user", content: ticket.text }],
  });
  const raw = response.content[0].text.trim();
  return raw === "none" ? [] : raw.split(",").map((t) => t.trim());
}
