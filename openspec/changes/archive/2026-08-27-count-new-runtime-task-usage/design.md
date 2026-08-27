# Design: Runtime-aware Pulse baselines

## Decision

Track which runtime adapters have completed one available snapshot. A task
first observed during that initial available snapshot is historical baseline
state and contributes no window delta. A task first observed after the runtime
baseline contributes its current token total exactly once; subsequent samples
contribute only positive increments.

## Failure boundaries

- An unavailable runtime is not marked baselined.
- Reconnecting/degraded snapshots retain the last verified task totals and do
  not create duplicate deltas.
- A task that temporarily disappears keeps its last total, so reappearance
  cannot replay its full usage.

## Verification example

After an empty Hermes snapshot, a newly completed 7,706-token Hermes session
must make all three Hermes counters read 7,706. If Hermes was unavailable at
startup and first recovers with that same historical session, the counters
remain zero until its total increases or another task is created.
