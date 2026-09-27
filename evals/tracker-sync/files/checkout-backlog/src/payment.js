// Hand-off to the payment provider's hosted page (ADR-0003). We send the
// amount and our order reference; card details are entered on the provider's
// page and never reach this service.
export function hostedPaymentRequest(order, totalPaise) {
  return {
    amount: totalPaise,
    currency: "INR",
    reference: order.orderNo,
    returnUrl: `/checkout/return?order=${encodeURIComponent(order.orderNo)}`,
  };
}
