# Postmortem: duplicate lab reports, 14 July 2026

Status: closed

## Summary

A partner lab retried 41 report webhooks after our acknowledgement call timed
out. Each retry was filed again, so 41 patients showed duplicate results for
about six hours.

## Actions

| Action | Ticket | State |
| --- | --- | --- |
| Alert on unacknowledged reports | LAB-205 | done |
| Unique index on (lab_id, patient_ref, collected_at) | LAB-212 | open |
| Retry the partner acknowledgement instead of dropping a 5xx | none yet | open |
