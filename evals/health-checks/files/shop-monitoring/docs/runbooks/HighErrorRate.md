# HighErrorRate

Fires when more than 5% of a service's requests return 5xx for 10 minutes.

1. Open the service's dashboard and find the failing route.
2. Check the last deploy; roll back if it lines up.
3. Check `/readyz` on the service for a failing dependency.
