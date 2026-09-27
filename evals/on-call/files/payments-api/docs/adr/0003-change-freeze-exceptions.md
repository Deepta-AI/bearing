# ADR-0003: What may ship during a change freeze

Status: Accepted

## Context
Storefront freezes feature releases around peak sales and after serious
incidents. payments-api is in PCI DSS scope: requirement 6.3.3 means
critical security patches must be installed within one month of release,
and our annual assessment committed us to seven days for critical patches
on in-scope services.

## Decision
No freeze of any kind, for any reason, blocks a security fix to
payments-api. Critical security patches ship within seven days of release,
through the normal review, even during a freeze. Any freeze policy written
for this service must carry this exception.

## Consequences
Freeze announcements for payments-api list the security exception.
