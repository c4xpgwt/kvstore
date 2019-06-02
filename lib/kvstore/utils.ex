defmodule Utils do

  def is_valid?(key, value, ttl) do
    is_binary(key) and is_binary(value) and is_integer(ttl) and ttl > 0
  end

  def is_valid_ttl?(ttl) do
    is_integer(ttl) and ttl > 0
  end

  def is_valid_value?(value) do
    is_binary(value)
  end

end