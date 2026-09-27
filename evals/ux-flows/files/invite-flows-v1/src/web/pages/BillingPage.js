import { PLANS } from '../../server/plans.js';

export function BillingPage({ workspace, seatsUsed }) {
  const plan = PLANS[workspace.plan];
  const limit = plan.seatLimit === null ? 'unlimited' : plan.seatLimit;
  return `<main>
  <h1>Billing</h1>
  <p>${plan.name} plan. Seats used: ${seatsUsed} of ${limit}.</p>
  ${workspace.plan === 'starter' ? `<a href="/settings/billing/upgrade">Upgrade to Pro ($${PLANS.pro.perSeatMonthlyUsd} per seat a month)</a>` : ''}
</main>`;
}
