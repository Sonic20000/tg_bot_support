from bot.models import UserThread
from bot.storage import ThreadStorage


def test_storage_roundtrip(tmp_path):
    path = tmp_path / "threads_data.json"
    storage = ThreadStorage(path)
    threads = {
        123: UserThread(
            user_id=123,
            user_name="Test User",
            username="test_user",
            thread_id=456,
            created_at="2026-06-03 10:00:00",
            last_active="2026-06-03 10:01:00",
        )
    }

    storage.save(threads)
    loaded = storage.load()

    assert loaded[123].user_name == "Test User"
    assert loaded[123].thread_id == 456
    assert loaded[123].username == "test_user"
