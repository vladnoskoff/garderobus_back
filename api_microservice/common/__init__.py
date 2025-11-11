"""Shared utilities and data transfer objects for microservices."""

from .messaging import EventMessage, publish_event

__all__ = ["EventMessage", "publish_event"]
