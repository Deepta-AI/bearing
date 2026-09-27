// Seat rules per plan. Starter caps seats; Pro adds a paid seat for every
// accepted invite (billing.js charges on accept).
export const PLANS = {
  starter: { name: 'Starter', seatLimit: 5, perSeatMonthlyUsd: 0 },
  pro: { name: 'Pro', seatLimit: null, perSeatMonthlyUsd: 8 },
};

export function planFor(workspace) {
  return PLANS[workspace.plan] ?? PLANS.starter;
}
