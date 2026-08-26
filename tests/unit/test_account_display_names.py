from app.modules.accounts.display_names import account_display_name


def test_display_name_uses_email_local_part_without_trailing_digits() -> None:
    assert account_display_name(email="m18247860@gmail.com") == "M"
    assert account_display_name(email="keyvan23@example.com") == "Keyvan"


def test_display_name_turns_email_separators_into_spaces() -> None:
    assert account_display_name(email="ali.reza_2024@example.com") == "Ali reza"


def test_display_name_preserves_unicode_letters() -> None:
    assert account_display_name(email="کیوان123@example.com") == "کیوان"


def test_display_name_uses_safe_fallback_when_local_part_is_numeric() -> None:
    assert account_display_name(email="12345@example.com") == "Account"
    assert account_display_name(email=None) == "Account"


def test_display_name_preserves_explicit_alias_as_operator_override() -> None:
    assert account_display_name(email="keyvan23@example.com", alias="  Main 23  ") == "Main 23"
