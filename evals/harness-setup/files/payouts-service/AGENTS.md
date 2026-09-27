# AGENTS.md

The engineering standard for every coding agent working in payouts-service.

## Code

- Go 1.25, standard library first. Money is an int64 in minor units, never a
  float.
- Table-driven tests next to the code (`*_test.go`); `make check` passes
  before a change is called done.
- Errors are wrapped with context and mapped to the codes in the reference
  below before they leave the service.
- Ask one question when the request is ambiguous; otherwise state your
  assumption and proceed.

## Error code reference

Every error the service returns to a merchant or writes to a settlement
report carries one of these codes. Keep the table in sync with
`internal/payout` when you add a code.

| Code | Area | Meaning | Merchant message | Retry |
| --- | --- | --- | --- | --- |
| PO-0001 | fee | merchant account suspended | Please update your bank details and retry. | no |
| PO-0002 | batch | KYC documents expired | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0003 | settlement | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | no |
| PO-0004 | bank | ledger balance insufficient for the payout | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0005 | merchant | settlement file checksum mismatch | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0006 | ledger | daily payout limit reached | Your payout is under review; no action is needed. | yes, next window |
| PO-0007 | limits | settlement file checksum mismatch | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0008 | kyc | daily payout limit reached | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0009 | fee | currency not enabled for the merchant | Please update your bank details and retry. | after merchant action |
| PO-0010 | batch | KYC documents expired | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0011 | settlement | ledger balance insufficient for the payout | Your payout is under review; no action is needed. | yes, next window |
| PO-0012 | bank | settlement file checksum mismatch | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0013 | merchant | bank rejected the account number | This payout will be retried in the next settlement window. | no |
| PO-0014 | ledger | bank rejected the account number | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0015 | limits | duplicate payout reference | Please update your bank details and retry. | yes, next window |
| PO-0016 | kyc | ledger balance insufficient for the payout | Please update your bank details and retry. | no |
| PO-0017 | fee | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0018 | batch | amount below the payout minimum | Please update your bank details and retry. | no |
| PO-0019 | settlement | KYC documents expired | Your payout is under review; no action is needed. | no |
| PO-0020 | bank | beneficiary name does not match the account | Your payout is under review; no action is needed. | no |
| PO-0021 | merchant | duplicate payout reference | Please update your bank details and retry. | yes, next window |
| PO-0022 | ledger | payout held for manual review | Please update your bank details and retry. | yes, next window |
| PO-0023 | limits | ledger balance insufficient for the payout | This payout will be retried in the next settlement window. | after merchant action |
| PO-0024 | kyc | beneficiary name does not match the account | This payout will be retried in the next settlement window. | after merchant action |
| PO-0025 | fee | beneficiary name does not match the account | This payout will be retried in the next settlement window. | after merchant action |
| PO-0026 | batch | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0027 | settlement | daily payout limit reached | Please update your bank details and retry. | no |
| PO-0028 | bank | bank rejected the account number | Your payout is under review; no action is needed. | no |
| PO-0029 | merchant | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0030 | ledger | ledger balance insufficient for the payout | This payout will be retried in the next settlement window. | no |
| PO-0031 | limits | payout held for manual review | This payout will be retried in the next settlement window. | after merchant action |
| PO-0032 | kyc | beneficiary name does not match the account | Your payout is under review; no action is needed. | yes, next window |
| PO-0033 | fee | currency not enabled for the merchant | This payout will be retried in the next settlement window. | no |
| PO-0034 | batch | payout held for manual review | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0035 | settlement | payout held for manual review | This payout will be retried in the next settlement window. | after merchant action |
| PO-0036 | bank | ledger balance insufficient for the payout | Your payout is under review; no action is needed. | no |
| PO-0037 | merchant | payout held for manual review | Your payout is under review; no action is needed. | after merchant action |
| PO-0038 | ledger | merchant account suspended | Your payout could not be processed. Contact support with this code. | no |
| PO-0039 | limits | merchant account suspended | Please update your bank details and retry. | after merchant action |
| PO-0040 | kyc | currency not enabled for the merchant | Your payout is under review; no action is needed. | yes, next window |
| PO-0041 | fee | settlement file checksum mismatch | This payout will be retried in the next settlement window. | yes, next window |
| PO-0042 | batch | payout held for manual review | Please update your bank details and retry. | no |
| PO-0043 | settlement | daily payout limit reached | Your payout is under review; no action is needed. | yes, next window |
| PO-0044 | bank | bank rejected the account number | Your payout is under review; no action is needed. | no |
| PO-0045 | merchant | bank cut-off time passed | This payout will be retried in the next settlement window. | yes, next window |
| PO-0046 | ledger | daily payout limit reached | This payout will be retried in the next settlement window. | after merchant action |
| PO-0047 | limits | daily payout limit reached | This payout will be retried in the next settlement window. | after merchant action |
| PO-0048 | kyc | daily payout limit reached | Please update your bank details and retry. | yes, next window |
| PO-0049 | fee | currency not enabled for the merchant | Please update your bank details and retry. | yes, next window |
| PO-0050 | batch | settlement file checksum mismatch | Please update your bank details and retry. | yes, next window |
| PO-0051 | settlement | beneficiary name does not match the account | Please update your bank details and retry. | no |
| PO-0052 | bank | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0053 | merchant | daily payout limit reached | This payout will be retried in the next settlement window. | after merchant action |
| PO-0054 | ledger | ledger balance insufficient for the payout | This payout will be retried in the next settlement window. | yes, next window |
| PO-0055 | limits | payout held for manual review | Your payout could not be processed. Contact support with this code. | no |
| PO-0056 | kyc | KYC documents expired | Your payout is under review; no action is needed. | no |
| PO-0057 | fee | daily payout limit reached | Your payout is under review; no action is needed. | yes, next window |
| PO-0058 | batch | beneficiary name does not match the account | Your payout is under review; no action is needed. | yes, next window |
| PO-0059 | settlement | settlement file checksum mismatch | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0060 | bank | beneficiary name does not match the account | Please update your bank details and retry. | yes, next window |
| PO-0061 | merchant | merchant account suspended | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0062 | ledger | amount below the payout minimum | Please update your bank details and retry. | after merchant action |
| PO-0063 | limits | currency not enabled for the merchant | This payout will be retried in the next settlement window. | after merchant action |
| PO-0064 | kyc | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0065 | fee | ledger balance insufficient for the payout | Your payout is under review; no action is needed. | yes, next window |
| PO-0066 | batch | KYC documents expired | This payout will be retried in the next settlement window. | no |
| PO-0067 | settlement | ledger balance insufficient for the payout | This payout will be retried in the next settlement window. | no |
| PO-0068 | bank | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | no |
| PO-0069 | merchant | beneficiary name does not match the account | Your payout is under review; no action is needed. | no |
| PO-0070 | ledger | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0071 | limits | currency not enabled for the merchant | This payout will be retried in the next settlement window. | after merchant action |
| PO-0072 | kyc | duplicate payout reference | Your payout is under review; no action is needed. | after merchant action |
| PO-0073 | fee | bank rejected the account number | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0074 | batch | bank cut-off time passed | This payout will be retried in the next settlement window. | yes, next window |
| PO-0075 | settlement | payout held for manual review | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0076 | bank | duplicate payout reference | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0077 | merchant | duplicate payout reference | This payout will be retried in the next settlement window. | yes, next window |
| PO-0078 | ledger | merchant account suspended | Please update your bank details and retry. | after merchant action |
| PO-0079 | limits | bank cut-off time passed | This payout will be retried in the next settlement window. | after merchant action |
| PO-0080 | kyc | settlement file checksum mismatch | Please update your bank details and retry. | yes, next window |
| PO-0081 | fee | daily payout limit reached | Please update your bank details and retry. | yes, next window |
| PO-0082 | batch | bank cut-off time passed | Your payout is under review; no action is needed. | no |
| PO-0083 | settlement | payout held for manual review | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0084 | bank | duplicate payout reference | Your payout is under review; no action is needed. | no |
| PO-0085 | merchant | settlement file checksum mismatch | This payout will be retried in the next settlement window. | no |
| PO-0086 | ledger | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0087 | limits | currency not enabled for the merchant | Please update your bank details and retry. | yes, next window |
| PO-0088 | kyc | settlement file checksum mismatch | Your payout is under review; no action is needed. | yes, next window |
| PO-0089 | fee | merchant account suspended | Please update your bank details and retry. | no |
| PO-0090 | batch | ledger balance insufficient for the payout | Your payout could not be processed. Contact support with this code. | no |
| PO-0091 | settlement | KYC documents expired | This payout will be retried in the next settlement window. | after merchant action |
| PO-0092 | bank | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | no |
| PO-0093 | merchant | payout held for manual review | Please update your bank details and retry. | no |
| PO-0094 | ledger | bank rejected the account number | Your payout is under review; no action is needed. | after merchant action |
| PO-0095 | limits | merchant account suspended | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0096 | kyc | daily payout limit reached | Your payout is under review; no action is needed. | no |
| PO-0097 | fee | payout held for manual review | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0098 | batch | bank rejected the account number | Please update your bank details and retry. | yes, next window |
| PO-0099 | settlement | amount below the payout minimum | Please update your bank details and retry. | after merchant action |
| PO-0100 | bank | beneficiary name does not match the account | Please update your bank details and retry. | after merchant action |
| PO-0101 | merchant | ledger balance insufficient for the payout | Your payout is under review; no action is needed. | after merchant action |
| PO-0102 | ledger | merchant account suspended | Please update your bank details and retry. | after merchant action |
| PO-0103 | limits | bank cut-off time passed | Please update your bank details and retry. | yes, next window |
| PO-0104 | kyc | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0105 | fee | payout held for manual review | Please update your bank details and retry. | no |
| PO-0106 | batch | settlement file checksum mismatch | Please update your bank details and retry. | yes, next window |
| PO-0107 | settlement | duplicate payout reference | Please update your bank details and retry. | no |
| PO-0108 | bank | bank cut-off time passed | Please update your bank details and retry. | after merchant action |
| PO-0109 | merchant | merchant account suspended | This payout will be retried in the next settlement window. | after merchant action |
| PO-0110 | ledger | daily payout limit reached | Please update your bank details and retry. | yes, next window |
| PO-0111 | limits | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0112 | kyc | KYC documents expired | Your payout is under review; no action is needed. | after merchant action |
| PO-0113 | fee | bank rejected the account number | Please update your bank details and retry. | after merchant action |
| PO-0114 | batch | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | no |
| PO-0115 | settlement | bank rejected the account number | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0116 | bank | bank rejected the account number | Please update your bank details and retry. | no |
| PO-0117 | merchant | ledger balance insufficient for the payout | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0118 | ledger | amount below the payout minimum | This payout will be retried in the next settlement window. | after merchant action |
| PO-0119 | limits | bank cut-off time passed | Your payout is under review; no action is needed. | yes, next window |
| PO-0120 | kyc | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0121 | fee | settlement file checksum mismatch | This payout will be retried in the next settlement window. | yes, next window |
| PO-0122 | batch | currency not enabled for the merchant | Your payout is under review; no action is needed. | after merchant action |
| PO-0123 | settlement | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | no |
| PO-0124 | bank | merchant account suspended | Please update your bank details and retry. | after merchant action |
| PO-0125 | merchant | duplicate payout reference | Your payout is under review; no action is needed. | after merchant action |
| PO-0126 | ledger | bank cut-off time passed | Your payout is under review; no action is needed. | after merchant action |
| PO-0127 | limits | settlement file checksum mismatch | This payout will be retried in the next settlement window. | after merchant action |
| PO-0128 | kyc | settlement file checksum mismatch | Your payout is under review; no action is needed. | yes, next window |
| PO-0129 | fee | daily payout limit reached | Your payout could not be processed. Contact support with this code. | no |
| PO-0130 | batch | beneficiary name does not match the account | This payout will be retried in the next settlement window. | yes, next window |
| PO-0131 | settlement | KYC documents expired | Please update your bank details and retry. | no |
| PO-0132 | bank | currency not enabled for the merchant | Please update your bank details and retry. | after merchant action |
| PO-0133 | merchant | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0134 | ledger | payout held for manual review | This payout will be retried in the next settlement window. | yes, next window |
| PO-0135 | limits | duplicate payout reference | Please update your bank details and retry. | no |
| PO-0136 | kyc | settlement file checksum mismatch | Your payout could not be processed. Contact support with this code. | no |
| PO-0137 | fee | beneficiary name does not match the account | Please update your bank details and retry. | after merchant action |
| PO-0138 | batch | settlement file checksum mismatch | Please update your bank details and retry. | after merchant action |
| PO-0139 | settlement | daily payout limit reached | Your payout is under review; no action is needed. | no |
| PO-0140 | bank | daily payout limit reached | Please update your bank details and retry. | no |
| PO-0141 | merchant | merchant account suspended | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0142 | ledger | merchant account suspended | Your payout could not be processed. Contact support with this code. | no |
| PO-0143 | limits | bank cut-off time passed | Your payout is under review; no action is needed. | no |
| PO-0144 | kyc | payout held for manual review | Your payout could not be processed. Contact support with this code. | no |
| PO-0145 | fee | merchant account suspended | This payout will be retried in the next settlement window. | after merchant action |
| PO-0146 | batch | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0147 | settlement | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | no |
| PO-0148 | bank | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0149 | merchant | duplicate payout reference | Please update your bank details and retry. | no |
| PO-0150 | ledger | KYC documents expired | This payout will be retried in the next settlement window. | no |
| PO-0151 | limits | bank rejected the account number | Your payout is under review; no action is needed. | after merchant action |
| PO-0152 | kyc | merchant account suspended | Your payout could not be processed. Contact support with this code. | no |
| PO-0153 | fee | amount below the payout minimum | Please update your bank details and retry. | no |
| PO-0154 | batch | currency not enabled for the merchant | This payout will be retried in the next settlement window. | yes, next window |
| PO-0155 | settlement | KYC documents expired | Your payout could not be processed. Contact support with this code. | no |
| PO-0156 | bank | currency not enabled for the merchant | Please update your bank details and retry. | yes, next window |
| PO-0157 | merchant | duplicate payout reference | Your payout could not be processed. Contact support with this code. | no |
| PO-0158 | ledger | amount below the payout minimum | This payout will be retried in the next settlement window. | after merchant action |
| PO-0159 | limits | daily payout limit reached | This payout will be retried in the next settlement window. | after merchant action |
| PO-0160 | kyc | bank rejected the account number | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0161 | fee | payout held for manual review | Please update your bank details and retry. | yes, next window |
| PO-0162 | batch | bank rejected the account number | This payout will be retried in the next settlement window. | yes, next window |
| PO-0163 | settlement | bank rejected the account number | Please update your bank details and retry. | no |
| PO-0164 | bank | KYC documents expired | This payout will be retried in the next settlement window. | after merchant action |
| PO-0165 | merchant | settlement file checksum mismatch | This payout will be retried in the next settlement window. | no |
| PO-0166 | ledger | bank cut-off time passed | Please update your bank details and retry. | no |
| PO-0167 | limits | merchant account suspended | Your payout could not be processed. Contact support with this code. | no |
| PO-0168 | kyc | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0169 | fee | payout held for manual review | Please update your bank details and retry. | after merchant action |
| PO-0170 | batch | beneficiary name does not match the account | Please update your bank details and retry. | no |
| PO-0171 | settlement | currency not enabled for the merchant | Your payout is under review; no action is needed. | after merchant action |
| PO-0172 | bank | beneficiary name does not match the account | Your payout is under review; no action is needed. | after merchant action |
| PO-0173 | merchant | duplicate payout reference | Please update your bank details and retry. | yes, next window |
| PO-0174 | ledger | merchant account suspended | Please update your bank details and retry. | after merchant action |
| PO-0175 | limits | payout held for manual review | Please update your bank details and retry. | no |
| PO-0176 | kyc | merchant account suspended | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0177 | fee | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0178 | batch | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0179 | settlement | bank rejected the account number | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0180 | bank | KYC documents expired | Your payout is under review; no action is needed. | after merchant action |
| PO-0181 | merchant | KYC documents expired | This payout will be retried in the next settlement window. | after merchant action |
| PO-0182 | ledger | settlement file checksum mismatch | This payout will be retried in the next settlement window. | yes, next window |
| PO-0183 | limits | beneficiary name does not match the account | Please update your bank details and retry. | yes, next window |
| PO-0184 | kyc | duplicate payout reference | Your payout is under review; no action is needed. | yes, next window |
| PO-0185 | fee | duplicate payout reference | This payout will be retried in the next settlement window. | no |
| PO-0186 | batch | bank cut-off time passed | This payout will be retried in the next settlement window. | yes, next window |
| PO-0187 | settlement | amount below the payout minimum | This payout will be retried in the next settlement window. | yes, next window |
| PO-0188 | bank | merchant account suspended | Please update your bank details and retry. | yes, next window |
| PO-0189 | merchant | merchant account suspended | Your payout is under review; no action is needed. | yes, next window |
| PO-0190 | ledger | beneficiary name does not match the account | This payout will be retried in the next settlement window. | after merchant action |
| PO-0191 | limits | KYC documents expired | Please update your bank details and retry. | yes, next window |
| PO-0192 | kyc | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0193 | fee | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0194 | batch | daily payout limit reached | Your payout could not be processed. Contact support with this code. | no |
| PO-0195 | settlement | amount below the payout minimum | This payout will be retried in the next settlement window. | no |
| PO-0196 | bank | KYC documents expired | Please update your bank details and retry. | yes, next window |
| PO-0197 | merchant | ledger balance insufficient for the payout | Please update your bank details and retry. | after merchant action |
| PO-0198 | ledger | payout held for manual review | Your payout is under review; no action is needed. | no |
| PO-0199 | limits | payout held for manual review | Your payout is under review; no action is needed. | yes, next window |
| PO-0200 | kyc | duplicate payout reference | Please update your bank details and retry. | yes, next window |
| PO-0201 | fee | payout held for manual review | Your payout is under review; no action is needed. | after merchant action |
| PO-0202 | batch | payout held for manual review | Please update your bank details and retry. | after merchant action |
| PO-0203 | settlement | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0204 | bank | ledger balance insufficient for the payout | Please update your bank details and retry. | yes, next window |
| PO-0205 | merchant | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0206 | ledger | KYC documents expired | This payout will be retried in the next settlement window. | yes, next window |
| PO-0207 | limits | daily payout limit reached | Your payout is under review; no action is needed. | after merchant action |
| PO-0208 | kyc | amount below the payout minimum | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0209 | fee | bank cut-off time passed | Please update your bank details and retry. | no |
| PO-0210 | batch | duplicate payout reference | Your payout could not be processed. Contact support with this code. | no |
| PO-0211 | settlement | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0212 | bank | bank cut-off time passed | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0213 | merchant | payout held for manual review | Your payout is under review; no action is needed. | no |
| PO-0214 | ledger | currency not enabled for the merchant | This payout will be retried in the next settlement window. | yes, next window |
| PO-0215 | limits | payout held for manual review | Please update your bank details and retry. | yes, next window |
| PO-0216 | kyc | payout held for manual review | Your payout is under review; no action is needed. | no |
| PO-0217 | fee | daily payout limit reached | Your payout could not be processed. Contact support with this code. | no |
| PO-0218 | batch | KYC documents expired | This payout will be retried in the next settlement window. | yes, next window |
| PO-0219 | settlement | ledger balance insufficient for the payout | Please update your bank details and retry. | yes, next window |
| PO-0220 | bank | ledger balance insufficient for the payout | Please update your bank details and retry. | no |
| PO-0221 | merchant | duplicate payout reference | This payout will be retried in the next settlement window. | after merchant action |
| PO-0222 | ledger | ledger balance insufficient for the payout | Please update your bank details and retry. | yes, next window |
| PO-0223 | limits | beneficiary name does not match the account | Your payout could not be processed. Contact support with this code. | no |
| PO-0224 | kyc | duplicate payout reference | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0225 | fee | settlement file checksum mismatch | Your payout is under review; no action is needed. | no |
| PO-0226 | batch | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0227 | settlement | beneficiary name does not match the account | Your payout is under review; no action is needed. | yes, next window |
| PO-0228 | bank | bank cut-off time passed | Please update your bank details and retry. | no |
| PO-0229 | merchant | currency not enabled for the merchant | Your payout is under review; no action is needed. | yes, next window |
| PO-0230 | ledger | duplicate payout reference | Your payout is under review; no action is needed. | yes, next window |
| PO-0231 | limits | bank cut-off time passed | Your payout is under review; no action is needed. | no |
| PO-0232 | kyc | daily payout limit reached | Please update your bank details and retry. | yes, next window |
| PO-0233 | fee | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0234 | batch | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0235 | settlement | bank rejected the account number | This payout will be retried in the next settlement window. | yes, next window |
| PO-0236 | bank | payout held for manual review | This payout will be retried in the next settlement window. | yes, next window |
| PO-0237 | merchant | beneficiary name does not match the account | Your payout is under review; no action is needed. | no |
| PO-0238 | ledger | amount below the payout minimum | Please update your bank details and retry. | yes, next window |
| PO-0239 | limits | beneficiary name does not match the account | Your payout is under review; no action is needed. | no |
| PO-0240 | kyc | duplicate payout reference | Please update your bank details and retry. | no |
| PO-0241 | fee | merchant account suspended | Your payout is under review; no action is needed. | no |
| PO-0242 | batch | currency not enabled for the merchant | This payout will be retried in the next settlement window. | yes, next window |
| PO-0243 | settlement | merchant account suspended | This payout will be retried in the next settlement window. | no |
| PO-0244 | bank | currency not enabled for the merchant | Please update your bank details and retry. | after merchant action |
| PO-0245 | merchant | amount below the payout minimum | This payout will be retried in the next settlement window. | no |
| PO-0246 | ledger | merchant account suspended | Your payout could not be processed. Contact support with this code. | no |
| PO-0247 | limits | daily payout limit reached | Your payout could not be processed. Contact support with this code. | no |
| PO-0248 | kyc | daily payout limit reached | This payout will be retried in the next settlement window. | yes, next window |
| PO-0249 | fee | duplicate payout reference | Your payout could not be processed. Contact support with this code. | yes, next window |
| PO-0250 | batch | KYC documents expired | This payout will be retried in the next settlement window. | after merchant action |
| PO-0251 | settlement | bank rejected the account number | Please update your bank details and retry. | no |
| PO-0252 | bank | daily payout limit reached | This payout will be retried in the next settlement window. | yes, next window |
| PO-0253 | merchant | merchant account suspended | Your payout is under review; no action is needed. | yes, next window |
| PO-0254 | ledger | KYC documents expired | Your payout is under review; no action is needed. | after merchant action |
| PO-0255 | limits | bank cut-off time passed | Please update your bank details and retry. | after merchant action |
| PO-0256 | kyc | currency not enabled for the merchant | Your payout could not be processed. Contact support with this code. | after merchant action |
| PO-0257 | fee | daily payout limit reached | Your payout is under review; no action is needed. | after merchant action |
| PO-0258 | batch | bank rejected the account number | This payout will be retried in the next settlement window. | no |
| PO-0259 | settlement | amount below the payout minimum | Please update your bank details and retry. | yes, next window |
| PO-0260 | bank | beneficiary name does not match the account | Your payout is under review; no action is needed. | no |
| PO-0261 | merchant | duplicate payout reference | This payout will be retried in the next settlement window. | no |
| PO-0262 | ledger | payout held for manual review | This payout will be retried in the next settlement window. | no |
| PO-0263 | limits | KYC documents expired | Please update your bank details and retry. | no |
| PO-0264 | kyc | beneficiary name does not match the account | Your payout is under review; no action is needed. | yes, next window |
| PO-0265 | fee | bank rejected the account number | Please update your bank details and retry. | yes, next window |
| PO-0266 | batch | settlement file checksum mismatch | Your payout is under review; no action is needed. | after merchant action |

## Git, releases and deploys

- Never push, merge, tag or deploy, on any branch, including release
  branches. A person does that. Prepare the command and print it instead.
- Never run `make deploy-payments` or `kubectl`; a person rolls out.
- Commits follow Conventional Commits, on a branch named
  `feature/PAY-<n>-<slug>`; never commit to main.
- The git hooks in `.githooks/` refuse a push unless a person types the
  branch name on the terminal. Run `make hooks` once after cloning.

## Report

End every task with: Changed, Verified, Not done, Noticed.
