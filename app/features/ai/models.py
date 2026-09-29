from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AIGenerationRun(Base):
    __tablename__ = "ai_generation_runs"
    __table_args__ = (
        CheckConstraint(
            "status IN ('running', 'succeeded', 'failed')",
            name="ck_ai_generation_runs_status",
        ),
        CheckConstraint(
            "validation_status IN ('pending', 'valid', 'invalid', 'not_run')",
            name="ck_ai_generation_runs_validation_status",
        ),
        CheckConstraint(
            "response_time_ms IS NULL OR response_time_ms >= 0",
            name="ck_ai_generation_runs_response_time_ms_non_negative",
        ),
        CheckConstraint(
            "prompt_tokens IS NULL OR prompt_tokens >= 0",
            name="ck_ai_generation_runs_prompt_tokens_non_negative",
        ),
        CheckConstraint(
            "completion_tokens IS NULL OR completion_tokens >= 0",
            name="ck_ai_generation_runs_completion_tokens_non_negative",
        ),
        CheckConstraint(
            "total_tokens IS NULL OR total_tokens >= 0",
            name="ck_ai_generation_runs_total_tokens_non_negative",
        ),
    )

    ai_generation_run_id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"),
        index=True,
    )
    request_purpose: Mapped[str] = mapped_column(String(100), index=True)
    model_role: Mapped[str] = mapped_column(String(50), index=True)
    model_id: Mapped[str] = mapped_column(String(255))
    prompt_version: Mapped[str] = mapped_column(String(50))
    status: Mapped[str] = mapped_column(String(50), index=True)
    validation_status: Mapped[str] = mapped_column(
        String(50),
        default="pending",
        server_default=text("'pending'"),
    )
    response_time_ms: Mapped[int | None] = mapped_column(Integer)
    prompt_tokens: Mapped[int | None] = mapped_column(Integer)
    completion_tokens: Mapped[int | None] = mapped_column(Integer)
    total_tokens: Mapped[int | None] = mapped_column(Integer)
    error_message: Mapped[str | None] = mapped_column(Text)
    input_summary: Mapped[dict | None] = mapped_column(JSON)
    output_summary: Mapped[dict | None] = mapped_column(JSON)
    fallback_used: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        server_default=text("false"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )
