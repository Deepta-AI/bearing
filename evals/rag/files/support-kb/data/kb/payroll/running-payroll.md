# Running payroll

Updated: 2026-08-02

A payroll run has four steps: lock attendance, preview, approve, and
disburse.

## 1. Lock attendance

Under Time > Lock month, lock the month. Leave applied after the lock goes
into the next month's run as a correction. A run cannot start while the
month is unlocked (error E-3002).

## 2. Preview

The preview shows gross, deductions and net pay per employee, and flags
anyone with negative net pay (E-3005) or no salary structure (E-3009).
Download the preview register as Excel to check it offline.

## 3. Approve

An admin with the Payroll approver role approves the run. Approval freezes
the payslips. To change an approved run, use Reopen run; each reopen is
logged in the audit trail with the user and time.

## 4. Disburse

Generate the bank file for your bank under Payroll > Disburse, upload it in
your bank's corporate portal, then mark the run as paid. Payslips are
emailed to employees when the run is marked as paid, not when it is
approved.


---
Was this article helpful? If you still need help, open a chat from the
Help menu or write to help@ledgerleaf.example. Ledgerleaf Payroll support is
available Monday to Saturday, 9:00 to 19:00 IST. Copyright 2026 Ledgerleaf
Technologies. All rights reserved.
