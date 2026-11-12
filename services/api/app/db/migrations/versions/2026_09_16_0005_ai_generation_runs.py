"""add ai generation run logs

Revision ID: 0005_ai_generation_runs
Revises: 0004_recommendation_stability
Create Date: 2026-09-16 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "0005_ai_generation_runs"
down_revision: str | Sequence[str] | None = "0004_recommendation_stability"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ai_generation_runs",
        sa.Column("ai_generation_run_id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("request_purpose", sa.String(length=100), nullable=False),
        sa.Column("model_role", sa.String(length=50), nullable=False),
        sa.Column("model_id", sa.String(length=255), nullable=False),
        sa.Column("prompt_version", sa.String(length=50), nullable=False),
        sa.Column("status", sa.String(length=50), nullable=False),
        sa.Column(
            "validation_status",
            sa.String(length=50),
            server_default=sa.text("'pending'"),
            nullable=False,
        ),
        sa.Column("response_time_ms", sa.Integer(), nullable=True),
        sa.Column("prompt_tokens", sa.Integer(), nullable=True),
        sa.Column("completion_tokens", sa.Integer(), nullable=True),
        sa.Column("total_tokens", sa.Integer(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("input_summary", sa.JSON(), nullable=True),
        sa.Column("output_summary", sa.JSON(), nullable=True),
        sa.Column(
            "fallback_used",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint(
            "status IN ('running', 'succeeded', 'failed')",
            name=op.f("ck_ai_generation_runs_status"),
        ),
        sa.CheckConstraint(
            "validation_status IN ('pending', 'valid', 'invalid', 'not_run')",
            name=op.f("ck_ai_generation_runs_validation_status"),
        ),
        sa.CheckConstraint(
            "response_time_ms IS NULL OR response_time_ms >= 0",
            name=op.f("ck_ai_generation_runs_response_time_ms_non_negative"),
        ),
        sa.CheckConstraint(
            "prompt_tokens IS NULL OR prompt_tokens >= 0",
            name=op.f("ck_ai_generation_runs_prompt_tokens_non_negative"),
        ),
        sa.CheckConstraint(
            "completion_tokens IS NULL OR completion_tokens >= 0",
            name=op.f("ck_ai_generation_runs_completion_tokens_non_negative"),
        ),
        sa.CheckConstraint(
            "total_tokens IS NULL OR total_tokens >= 0",
            name=op.f("ck_ai_generation_runs_total_tokens_non_negative"),
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.user_id"],
            name=op.f("fk_ai_generation_runs_user_id_users"),
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "ai_generation_run_id",
            name=op.f("pk_ai_generation_runs"),
        ),
    )
    op.create_index(
        op.f("ix_ai_generation_runs_ai_generation_run_id"),
        "ai_generation_runs",
        ["ai_generation_run_id"],
    )
    op.create_index(
        op.f("ix_ai_generation_runs_model_role"),
        "ai_generation_runs",
        ["model_role"],
    )
    op.create_index(
        op.f("ix_ai_generation_runs_request_purpose"),
        "ai_generation_runs",
        ["request_purpose"],
    )
    op.create_index(
        op.f("ix_ai_generation_runs_status"),
        "ai_generation_runs",
        ["status"],
    )
    op.create_index(
        op.f("ix_ai_generation_runs_user_id"),
        "ai_generation_runs",
        ["user_id"],
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_ai_generation_runs_user_id"), table_name="ai_generation_runs")
    op.drop_index(op.f("ix_ai_generation_runs_status"), table_name="ai_generation_runs")
    op.drop_index(
        op.f("ix_ai_generation_runs_request_purpose"),
        table_name="ai_generation_runs",
    )
    op.drop_index(
        op.f("ix_ai_generation_runs_model_role"),
        table_name="ai_generation_runs",
    )
    op.drop_index(
        op.f("ix_ai_generation_runs_ai_generation_run_id"),
        table_name="ai_generation_runs",
    )
    op.drop_table("ai_generation_runs")
