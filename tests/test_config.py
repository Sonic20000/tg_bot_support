import os

import pytest

from bot.config import ConfigError, load_settings, parse_int_list, parse_support_group_id


def test_parse_support_group_id_accepts_bot_api_supergroup_id():
    assert parse_support_group_id("-1001234567890") == -1001234567890


@pytest.mark.parametrize("value", ["", "123", "-123", "not-an-int"])
def test_parse_support_group_id_rejects_invalid_values(value):
    with pytest.raises(ConfigError):
        parse_support_group_id(value)


def test_parse_int_list():
    assert parse_int_list("1, 2,3", "ADMIN_IDS") == [1, 2, 3]


def test_load_settings_from_env_file(tmp_path, monkeypatch):
    for key in ("BOT_TOKEN", "SUPPORT_GROUP_ID", "ADMIN_IDS", "OPERATOR_IDS", "DATA_FILE"):
        monkeypatch.delenv(key, raising=False)
    env_file = tmp_path / ".env"
    env_file.write_text(
        "BOT_TOKEN=token\n"
        "SUPPORT_GROUP_ID=-1001234567890\n"
        "ADMIN_IDS=1,2\n"
        "DATA_FILE=/tmp/custom.json\n",
        encoding="utf-8",
    )

    settings = load_settings(env_file)

    assert settings.bot_token == "token"
    assert settings.support_group_id == -1001234567890
    assert settings.admin_ids == [1, 2]
    assert os.fspath(settings.data_file) == "/tmp/custom.json"
