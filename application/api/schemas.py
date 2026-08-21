from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class HealthResponse(BaseModel):
    status: str
    service: str
    environment: str


class ReadyResponse(BaseModel):
    status: str
    checks: dict[str, bool]


class CustomerCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: EmailStr


class Customer(BaseModel):
    id: UUID
    name: str
    email: EmailStr
    created_at: datetime


class JobCreate(BaseModel):
    job_type: str = Field(default="csv_report", min_length=1, max_length=100)
    payload: dict[str, Any] = Field(default_factory=dict)


class Job(BaseModel):
    id: UUID
    job_type: str
    status: str
    payload: dict[str, Any]
    attempts: int
    last_error: str | None = None
    created_at: datetime
    updated_at: datetime
    result: dict[str, Any] | None = None
    object_key: str | None = None
    object_type: str | None = None

