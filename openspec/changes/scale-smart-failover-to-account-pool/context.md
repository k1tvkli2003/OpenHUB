# Bounded full-pool failover

OpenHUB currently manages fifteen local accounts. A recognized quota failure
that arrives before any downstream-visible output is safe to replay because the
client has not observed a partial response. The failed account is excluded from
the current request, so the next selector pass can choose the best remaining
eligible account.

The traversal remains bounded at sixteen distinct account attempts and by the
existing request deadline. Sixteen covers the current fleet while preventing an
unbounded retry loop if state changes concurrently. Selection can still stop
earlier when no eligible account remains.

This does not weaken ownership rules. Requests pinned by uploaded file IDs,
hard previous-response continuity, or visible downstream output remain
fail-closed and are not replayed across accounts.

Example: accounts A, B, and C return `usage_limit_reached` before the first SSE
event. Each is marked/excluded. Account D is selected next and completes. The
client receives only D's successful response and no quota event from A-C.
