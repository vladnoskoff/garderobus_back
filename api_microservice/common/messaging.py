"""Simple event abstraction for cross-service communication."""

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict


@dataclass
class EventMessage:
    """Represents a domain event produced by a service."""

    event_type: str
    payload: Dict[str, Any]
    produced_at: datetime = datetime.now(timezone.utc)


def publish_event(event: EventMessage) -> None:
    """Placeholder for publishing events to the broker.

    Replace this implementation with concrete RabbitMQ/Kafka producers
    when wiring the services together.
    """

    # In a real implementation this would push to RabbitMQ/Kafka/etc.
    print(f"[EVENT] {event.event_type}: {event.payload}")
