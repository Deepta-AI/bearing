import { api } from "./client";

// Payout approvals API (payline-api v3, /api/payouts). Amounts are integer paise.
//
// Status lifecycle:
//   pending -> approved -> paid | failed
//   pending -> awaiting_second_approval -> approved   (REQ-304, see below)
//   pending | awaiting_second_approval -> rejected
//
// A payout of 50,000,000 paise or more needs two different approvers: the
// first POST /approve moves it to awaiting_second_approval and records
// first_approver; the same user approving again gets 409 same_approver.
export type PayoutStatus = "pending" | "awaiting_second_approval" | "approved" | "rejected" | "paid" | "failed";

export const TWO_APPROVER_THRESHOLD_PAISE = 50_000_000;
export const PAGE_SIZE = 25;
export const REJECT_REASON_MIN = 10;

export interface Approver {
  id: string;
  name: string;
  approved_at: string;
}

export interface Payout {
  id: string;
  vendor_id: string;
  vendor_name: string;
  invoice_ref: string;
  amount_paise: number;
  status: PayoutStatus;
  due_on: string;
  created_at: string;
  first_approver: Approver | null;
  rejection_reason: string | null;
  failure_reason: string | null;
}

export interface PayoutPage {
  items: Payout[];
  total: number;
  page: number;
}

// Errors the approve and reject calls return (ApiError.code):
//   403 over_limit        amount above the caller's approval limit (REQ-306)
//   409 already_decided   someone else approved or rejected it first
//   409 same_approver     the first approver tried to give the second approval
//   422 reason_too_short  rejection reason under REJECT_REASON_MIN characters
export function listPayoutsForApproval(page = 1) {
  return api<PayoutPage>(`/payouts?status=pending,awaiting_second_approval&page=${page}`);
}

export function getPayout(id: string) {
  return api<Payout>(`/payouts/${id}`);
}

export function approvePayout(id: string) {
  return api<Payout>(`/payouts/${id}/approve`, { method: "POST" });
}

export function rejectPayout(id: string, reason: string) {
  return api<Payout>(`/payouts/${id}/reject`, { method: "POST", body: JSON.stringify({ reason }) });
}
