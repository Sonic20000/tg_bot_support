from bot.services.formatting import html_escape, make_topic_name, trim_text


def test_html_escape_escapes_user_content():
    assert html_escape("<b>hello</b>") == "&lt;b&gt;hello&lt;/b&gt;"


def test_topic_name_is_limited():
    assert len(make_topic_name("x" * 200)) <= 128


def test_trim_text():
    assert trim_text("abcdef", 5) == "ab..."
