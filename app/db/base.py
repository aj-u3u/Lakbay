from importlib import import_module
from pathlib import Path

from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase


NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(column_0_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING_CONVENTION)


def import_model_modules() -> None:
    """Import feature model modules so Alembic can discover metadata."""
    features_dir = Path(__file__).resolve().parents[1] / "features"

    if not features_dir.exists():
        return

    for models_file in features_dir.glob("*/models.py"):
        feature_name = models_file.parent.name
        import_module(f"app.features.{feature_name}.models")
