from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.concurrency import run_in_threadpool

from app.core.auth.dependencies import set_dashboard_error_format, validate_dashboard_session
from app.modules.storage_cleanup import service
from app.modules.storage_cleanup.schemas import (
    StorageCleanupApplyRequest,
    StorageCleanupApplyResponse,
    StorageCleanupCandidateResponse,
    StorageCleanupPreviewResponse,
    StorageCleanupRequest,
)

router = APIRouter(
    prefix="/api/storage-cleanup",
    tags=["dashboard"],
    dependencies=[Depends(validate_dashboard_session), Depends(set_dashboard_error_format)],
)


@router.post("/preview", response_model=StorageCleanupPreviewResponse)
async def preview_storage_cleanup(payload: StorageCleanupRequest) -> StorageCleanupPreviewResponse:
    preview = await run_in_threadpool(
        service.preview_cleanup,
        categories=payload.categories,
        older_than_days=payload.older_than_days,
    )
    return _preview_response(preview)


@router.post("/apply", response_model=StorageCleanupApplyResponse)
async def apply_storage_cleanup(payload: StorageCleanupApplyRequest) -> StorageCleanupApplyResponse:
    try:
        result = await run_in_threadpool(
            service.apply_cleanup,
            categories=payload.categories,
            older_than_days=payload.older_than_days,
            confirmation_token=payload.confirmation_token,
        )
    except service.StorageCleanupPreviewChangedError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return StorageCleanupApplyResponse(
        deleted_files=result.deleted_files,
        deleted_bytes=result.deleted_bytes,
        skipped_files=result.skipped_files,
    )


def _preview_response(preview: service.CleanupPreview) -> StorageCleanupPreviewResponse:
    return StorageCleanupPreviewResponse(
        older_than_days=preview.older_than_days,
        cutoff=preview.cutoff,
        file_count=len(preview.candidates),
        total_bytes=preview.total_bytes,
        confirmation_token=preview.confirmation_token,
        candidates=[
            StorageCleanupCandidateResponse(
                category=item.category,
                relative_path=item.relative_path,
                size_bytes=item.size_bytes,
                modified_at=item.modified_at,
            )
            for item in preview.candidates
        ],
    )
