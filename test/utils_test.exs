defmodule UtilsTest do
  use ExUnit.Case, async: true

  import Utils

  test "Utils.is_valid?/3" do
    refute is_valid?(1, "10", 100)
    refute is_valid?("1", "10", -100)
    refute is_valid?("1", "10", 0)
    refute is_valid?("a", "10", "1")
    refute is_valid?("a", 10, 1)
    refute is_valid?(:ok, "a", 1)
    assert is_valid?("a", "a", 100)
  end

  test "Utils.is_valid_value?/1" do
    refute is_valid_value?(100)
    refute is_valid_value?(:ok)
    refute is_valid_value?([])
    assert is_valid_value?("a")
  end

  test "Utils.is_valid_ttl?/1" do
    refute is_valid_ttl?(-100)
    refute is_valid_ttl?(2.0)
    refute is_valid_ttl?([])
    refute is_valid_ttl?("a")
    assert is_valid_ttl?(1)
  end
end
