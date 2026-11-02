from io import StringIO

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory

from app.core.config import get_settings


def test_migration_history_has_one_head_and_generates_offline_sql(monkeypatch) -> None:
    # Offline SQL generation checks the Alembic graph without touching Neon.
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://test:test@localhost/lakbay_test")
    get_settings.cache_clear()
    config = Config("alembic.ini")
    script = ScriptDirectory.from_config(config)
    assert len(script.get_heads()) == 1

    upgrade_output = StringIO()
    config.output_buffer = upgrade_output
    command.upgrade(config, "head", sql=True)
    upgrade_sql = upgrade_output.getvalue()
    assert "CREATE TABLE users" in upgrade_sql
    assert "CREATE TABLE destinations" in upgrade_sql
    assert "estimated_cost" in upgrade_sql

    downgrade_output = StringIO()
    config.output_buffer = downgrade_output
    command.downgrade(config, "head:base", sql=True)
    downgrade_sql = downgrade_output.getvalue()
    assert "DROP TABLE" in downgrade_sql
    get_settings.cache_clear()
