"""Assigns queued deliveries to riders."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Rider:
    rider_id: str
    capacity: int


def assign(deliveries, riders):
    """Round-robin deliveries over riders, never past a rider's capacity.

    Returns (assignments, unassigned) where assignments maps rider_id to a
    list of delivery ids.
    """
    assignments = {r.rider_id: [] for r in riders}
    unassigned = []
    open_riders = [r for r in riders if r.capacity > 0]
    i = 0
    for d in deliveries:
        if not open_riders:
            unassigned.append(d)
            continue
        r = open_riders[i % len(open_riders)]
        assignments[r.rider_id].append(d)
        if len(assignments[r.rider_id]) >= r.capacity:
            open_riders.remove(r)
        else:
            i += 1
    return assignments, unassigned
