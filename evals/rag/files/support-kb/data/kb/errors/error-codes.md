# Error codes

Updated: 2026-08-28

Error codes appear in red banners in the app and in the payroll run log.
Search this page for the code you see.

| Code | Where you see it | Meaning | What to do |
| --- | --- | --- | --- |
| E-1001 | Login | Password expired | Reset the password from the login page |
| E-1004 | Login | Account locked after 5 failed attempts | Wait 30 minutes or ask an admin to unlock |
| E-1010 | Login | SSO assertion rejected | Check the IdP certificate has not expired |
| E-2003 | Employee import | Duplicate employee code in the file | Make employee codes unique and import again |
| E-2007 | Employee import | Date of joining after the payroll month | Fix the date or move the employee to next month |
| E-2011 | Employee import | PAN format invalid | PAN must be 5 letters, 4 digits, 1 letter |
| E-3002 | Payroll run | Attendance not locked for the month | Lock attendance under Time > Lock month |
| E-3005 | Payroll run | Negative net pay for one or more employees | Review loans and deductions for the listed employees |
| E-3009 | Payroll run | Salary structure missing for an employee | Assign a structure under Employee > Compensation |
| E-3014 | Payroll run | Run blocked, subscription payment due | Pay the open invoice under Settings > Billing |
| E-4001 | Bank file | Bank file format not enabled on your plan | Upgrade or choose an enabled format |
| E-4006 | Bank file | Debit account number missing | Add the company debit account under Settings > Bank |
| E-4012 | Bank file | IFSC not valid for NEFT for one or more employees | Correct the IFSC in each listed employee's bank details; IFSCs of merged banks changed in 2020 and 2021 |
| E-4015 | Bank file | Amount exceeds the bank's per-file limit | Split the run into two bank files |
| E-5002 | PF filing | UAN not linked to Aadhaar | Ask the employee to link UAN and Aadhaar on the EPFO portal |
| E-5006 | PF filing | ECR total does not match the payroll register | Re-generate the ECR after the last payroll correction |
| E-5011 | ESI filing | IP number missing for an ESI-eligible employee | Register the employee on the ESIC portal and add the IP number |
| E-6001 | TDS | Tax regime not declared | Employee or admin sets the regime under Tax > Declarations |
| E-6004 | TDS | Form 16 part A not uploaded | Upload part A from TRACES before generating Form 16 |
| E-7002 | Integrations | Webhook endpoint returned 4xx five times | Fix the endpoint, then re-enable the webhook |
| E-7008 | Integrations | API rate limit exceeded | Keep under 10 requests per second per company |


---
Was this article helpful? If you still need help, open a chat from the
Help menu or write to help@ledgerleaf.example. Ledgerleaf Payroll support is
available Monday to Saturday, 9:00 to 19:00 IST. Copyright 2026 Ledgerleaf
Technologies. All rights reserved.
