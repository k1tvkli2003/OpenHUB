from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

CleanupCategory = Literal["conversation_archives", "debug_dumps", "temporary_files"]


class StorageCleanupRequest(BaseModel):
    categories: list[CleanupCategory] = Field(min_length=1, max_length=3)
    older_than_days: int = Field(default=30, alias="olderThanDays", ge=1, le=3650)

    @field_validator("categories")
    @classmethod
    def _unique_categories(cls, value: list[CleanupCategory]) -> list[CleanupCategory]:
        return list(dict.fromkeys(value))


class StorageCleanupApplyRequest(StorageCleanupRequest):
    confirmation_token: str = Field(alias="confirmationToken", min_length=64, max_length=64)


class StorageCleanupCandidateResponse(BaseModel):
    category: CleanupCategory
    relative_path: str = Field(alias="relativePath")
    size_bytes: int = Field(alias="sizeBytes", ge=0)
    modified_at: datetime = Field(alias="modifiedAt")

    model_config = {"populate_by_name": True}


class StorageCleanupPreviewResponse(BaseModel):
    older_than_days: int = Field(alias="olderThanDays")
    cutoff: datetime
    file_count: int = Field(alias="fileCount")
    total_bytes: int = Field(alias="totalBytes")
    confirmation_token: str = Field(alias="confirmationToken")
    candidates: list[StorageCleanupCandidateResponse]
    protected_runtime_stores: bool = Field(default=True, alias="protectedRuntimeStores")

    model_config = {"populate_by_name": True}


class StorageCleanupApplyResponse(BaseModel):
    deleted_files: int = Field(alias="deletedFiles")
    deleted_bytes: int = Field(alias="deletedBytes")
    skipped_files: int = Field(alias="skippedFiles")
    protected_runtime_stores: bool = Field(default=True, alias="protectedRuntimeStores")

    model_config = {"populate_by_name": True}
