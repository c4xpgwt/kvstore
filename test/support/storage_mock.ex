defmodule StorageMock do
  @behaviour Storage.Behaviour

  def get_all() do [{"key 1", "value 1", 1000}, {"key 2", "value 2", 1000}, {"key 3", "value 3", 1000}] end

  def get("a") do {"key 1", "value 1", 1000} end
  def get("b") do :none end

  def add("a", _value, _ttl) do :already_exists end
  def add("b", _value, _ttl) do :ok end

  def delete("a") do :ok end
  def delete("b") do :none end

  def update("a", _value) do :ok end
  def update("b", _value) do :none end

  def set_ttl("a", _ttl) do :ok end
  def set_ttl("b", _ttl) do :none end

  def get_ttl("a") do 10 end
  def get_ttl("b") do :none end

end
