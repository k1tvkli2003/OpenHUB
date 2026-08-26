from __future__ import annotations

import asyncio
from typing import Any


async def stop_periodic_task(task: asyncio.Task[Any], stop_event: asyncio.Event) -> None:
    """Stop an event-driven task without cancelling in-flight resource work.

    Periodic database loops use ``stop_event`` to wake their interval wait.
    Cancelling one while an async driver is still acquiring a connection can
    orphan the driver's worker after the event loop closes. Signal the task and
    let its current iteration release resources first. If this stop operation
    is itself cancelled, cleanup still finishes before cancellation propagates.
    """

    stop_event.set()
    try:
        await asyncio.shield(task)
    except asyncio.CancelledError:
        current = asyncio.current_task()
        if current is not None and current.cancelling():
            try:
                await task
            except asyncio.CancelledError:
                pass
            raise
        # Preserve tolerance for a child task cancelled by an external owner.
