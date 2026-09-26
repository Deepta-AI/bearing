// SMTP relay client.

export const SMTP_TIMEOUT_MS = 60_000;

// The relay answered 4xx or timed out; the same message may succeed later.
export class TemporaryFailure extends Error {}

// The relay answered 5xx (for example a bad address); retrying will not help.
export class PermanentFailure extends Error {}

export class Mailer {
  constructor(relay) {
    this.relay = relay;
  }

  async sendConfirmation(orderId, to, totalPaise) {
    const body = `Thanks for your order #${orderId}. Total: Rs ${(totalPaise / 100).toFixed(2)}`;
    await this.relay.send({ to, subject: `Order #${orderId} confirmed`, body, timeoutMs: SMTP_TIMEOUT_MS });
  }
}

// Test double: records sent mail; can be told to fail the first N sends.
export class FakeRelay {
  constructor({ failWith = null, failTimes = 0 } = {}) {
    this.sent = [];
    this.failWith = failWith;
    this.failTimes = failTimes;
  }

  async send({ to, subject, body }) {
    if (this.failWith && this.failTimes > 0) {
      this.failTimes -= 1;
      throw new this.failWith('relay said no');
    }
    this.sent.push({ to, subject, body });
  }
}
