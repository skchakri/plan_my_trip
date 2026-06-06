require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  test "encrypts the value at rest and round-trips it" do
    s = AppSetting.set("PERPLEXITY_API_KEY", "pplx-secret-123")
    assert_equal "pplx-secret-123", s.value
    refute_includes s.encrypted_value.to_s, "pplx-secret-123", "ciphertext must not contain the plaintext"
    # A fresh read from the DB still decrypts.
    assert_equal "pplx-secret-123", AppSetting.find_by(key: "PERPLEXITY_API_KEY").value
  end

  test "get precedence: DB override beats ENV which beats registry default" do
    key = "AFFILIATE_VIATOR_MCID" # has a registry default of 42383
    assert_equal "42383", AppSetting.get(key), "falls back to the registry default"

    ENV[key] = "env-mcid"
    assert_equal "env-mcid", AppSetting.get(key), "ENV beats the default"

    AppSetting.set(key, "db-mcid")
    assert_equal "db-mcid", AppSetting.get(key), "DB beats ENV"
  ensure
    ENV.delete("AFFILIATE_VIATOR_MCID")
  end

  test "set with a blank value clears an existing override" do
    AppSetting.set("OPENAI_API_KEY", "sk-abc")
    assert AppSetting.exists?(key: "OPENAI_API_KEY")
    assert_nil AppSetting.set("OPENAI_API_KEY", "  ")
    refute AppSetting.exists?(key: "OPENAI_API_KEY")
  end

  test "rejects keys outside the registry" do
    rec = AppSetting.new(key: "NOT_A_REAL_KEY", value: "x")
    refute rec.valid?
    assert_includes rec.errors[:key], "is not included in the list"
  end

  test "masked_hint reveals only the last four characters" do
    s = AppSetting.set("PIXABAY_API_KEY", "1234567890abcd")
    assert_equal "••••abcd", s.masked_hint
  end

  test "import_from_env! lifts a value into the DB and is idempotent" do
    key = "AFFILIATE_TRAVELPAYOUTS_MARKER"
    ENV[key] = "marker-xyz"
    imported = AppSetting.import_from_env!
    assert_includes imported, key
    assert_equal "marker-xyz", AppSetting.find_by(key: key).value

    # Second run does not re-import an already-present key.
    refute_includes AppSetting.import_from_env!, key
  ensure
    ENV.delete("AFFILIATE_TRAVELPAYOUTS_MARKER")
  end

  test "set? reflects whether an encrypted value is stored" do
    s = AppSetting.new(key: "PEXELS_API_KEY")
    refute s.set?
    s.value = "abc"
    assert s.set?
  end
end
