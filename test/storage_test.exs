defmodule StorageTest do
  use ExUnit.Case, async: false

  import Storage

  @table_name   Application.get_env(:kvstore, :tab_name)

  setup_all do
    {:ok, pid} = start_supervised(KVStore.Supervisor)
    :dets.delete_all_objects(@table_name)

    {:ok, sup_pid: pid}
  end

  test "testing add, get, update, delete, set ttl, get ttl functional" do
    key = "key1"
    value = "value1"
    new_value = "new value"
    ttl = 5

    assert add(key, value, ttl) == :ok
    assert add(key, value, ttl) == :already_exists

    add("key2", "value2", 2)
    add("key3", "value3", 2)

    {select_key, select_value, select_ttl} = get(key)
    assert select_key == key
    assert select_value == value
    assert select_ttl <= ttl and ttl - select_ttl < 2
    assert length(get_all()) == 3

    assert delete(key) == :ok
    assert delete(key) == :none

    assert get(key) == :none
    assert length(get_all()) == 2

    assert update(key, value) == :none

    add(key, value, ttl)
    assert update(key, new_value) == :ok

    {select_key, select_value, _select_ttl} = get(key)
    assert select_key == key
    assert select_value == new_value

    select_ttl = get_ttl(key)
    assert get_ttl("not_existing_key") == :none
    assert is_integer(select_ttl) and select_ttl <= ttl

    new_ttl = 15
    assert set_ttl("not_existing_key", new_ttl) == :none
    assert set_ttl(key, new_ttl) == :ok
    assert new_ttl - get_ttl(key) < 2 and get_ttl(key) > ttl
  end

  test "call methods with illegal arguments" do
    assert_raise ArgumentError, fn -> get(:ok) end
    assert_raise ArgumentError, fn -> get([]) end
    assert_raise ArgumentError, fn -> add(:ok, "value", 100) end
    assert_raise ArgumentError, fn -> add("key", "value", 0) end
    assert_raise ArgumentError, fn -> add("key", "value", -1) end
    assert_raise ArgumentError, fn -> add("key", 1, 100) end
    assert_raise ArgumentError, fn -> add("key", :ok, 100) end
    assert_raise ArgumentError, fn -> delete(:ok) end
    assert_raise ArgumentError, fn -> delete(100) end
    assert_raise ArgumentError, fn -> update(:ok, "value") end
    assert_raise ArgumentError, fn -> update("key", :ok) end
    assert_raise ArgumentError, fn -> update("key", 1) end
    assert_raise ArgumentError, fn -> set_ttl("key", 0) end
    assert_raise ArgumentError, fn -> set_ttl("key", -10) end
    assert_raise ArgumentError, fn -> set_ttl(1, 10) end
    assert_raise ArgumentError, fn -> get_ttl(:ok) end
    assert_raise ArgumentError, fn -> get_ttl([]) end
  end

  test "dets table does not contain record after ttl expiry" do
    key_1 = "key_1"
    ttl_1 = 1
    key_2 = "key_2"
    ttl_2 = ttl_1 + 1

    delete(key_1)
    delete(key_2)
    add(key_1, "value", ttl_1)
    add(key_2, "value", ttl_2)

    assert get(key_1) != :none
    assert :dets.lookup(@table_name, key_1) != []
    assert get(key_2) != :none
    assert :dets.lookup(@table_name, key_2) != []

    :timer.sleep(ttl_1 * 1000)

    assert get(key_1) == :none
    assert :dets.lookup(@table_name, key_1) == []
    assert get(key_2) != :none
    assert :dets.lookup(@table_name, key_2) != []

    :timer.sleep((ttl_2 - ttl_1) * 1000)

    assert get(key_2) == :none
    assert :dets.lookup(@table_name, key_2) == []
  end

end