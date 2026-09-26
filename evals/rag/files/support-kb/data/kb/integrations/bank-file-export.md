# Bank file export

Updated: 2026-08-19

Ledgerleaf generates salary bank files in 19 bank formats. Starter plans can
use three formats, Growth twelve, Scale and Enterprise all 19 (see "Plans
and limits").

## Choosing a format

Under Settings > Bank, pick your bank and file format. If your bank is not
in the list, use the generic NEFT CSV format, which most corporate portals
accept.

## Validation before export

Before a file is generated, every employee's IFSC is checked against the
current RBI IFSC list. Employees whose IFSC no longer exists, usually after
a bank merger, block the file with error E-4012 and are listed so you can
correct them. A file larger than the bank's per-file limit is rejected with
E-4015; split the run.

## Encryption

Files for banks that require it are encrypted with the key you upload under
Settings > Bank > Encryption keys. The key is never shown again after
upload.


---
Was this article helpful? If you still need help, open a chat from the
Help menu or write to help@ledgerleaf.example. Ledgerleaf Payroll support is
available Monday to Saturday, 9:00 to 19:00 IST. Copyright 2026 Ledgerleaf
Technologies. All rights reserved.
