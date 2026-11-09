"""Add completed-trip mobile app assessments.

Revision ID: 2026_11_09_0900
Revises: 2026_11_04_0800
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "2026_11_09_0900"
down_revision: str | Sequence[str] | None = "2026_11_04_0800"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


RATING_FIELDS = (
    "functional_suitability_rating",
    "information_accuracy_rating",
    "performance_rating",
    "interaction_rating",
    "reliability_rating",
    "sharing_clarity_rating",
)


def upgrade() -> None:
    op.create_table(
        "app_assessments",
        sa.Column("app_assessment_id", sa.Integer(), primary_key=True),
        sa.Column("trip_id", sa.Integer(), sa.ForeignKey("trips.trip_id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_version", sa.Integer(), nullable=False),
        *(sa.Column(field, sa.Integer(), nullable=True) for field in RATING_FIELDS),
        sa.Column("comment", sa.Text()),
        sa.Column("app_version", sa.String(32)),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("trip_id", "user_id", name="uq_app_assessments_trip_user"),
        sa.ForeignKeyConstraint(
            ["trip_id", "user_id"],
            ["trip_members.trip_id", "trip_members.user_id"],
            name="fk_app_assessments_member_same_trip",
            ondelete="RESTRICT",
        ),
        sa.CheckConstraint("question_version >= 1", name="ck_app_assessments_question_version_positive"),
        sa.CheckConstraint(
            " OR ".join(f"{field} IS NOT NULL" for field in RATING_FIELDS),
            name="ck_app_assessments_one_rating_required",
        ),
        *(
            sa.CheckConstraint(
                f"{field} IS NULL OR {field} BETWEEN 1 AND 5",
                name=f"ck_app_assessments_{field}_range",
            )
            for field in RATING_FIELDS
        ),
    )
    op.create_index("ix_app_assessments_trip_id", "app_assessments", ["trip_id"])
    op.create_index("ix_app_assessments_user_id", "app_assessments", ["user_id"])
    op.create_index("ix_app_assessments_submitted_at", "app_assessments", ["submitted_at"])


def downgrade() -> None:
    op.drop_index("ix_app_assessments_submitted_at", table_name="app_assessments")
    op.drop_index("ix_app_assessments_user_id", table_name="app_assessments")
    op.drop_index("ix_app_assessments_trip_id", table_name="app_assessments")
    op.drop_table("app_assessments")
