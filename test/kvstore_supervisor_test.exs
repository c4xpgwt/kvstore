defmodule KVStore.SupervisorTest do
  use ExUnit.Case, async: false

  setup_all do
    {:ok, pid} = start_supervised(KVStore.Supervisor)
    {:ok, sup_pid: pid}
  end

  test "supervisor and children started", context do
    children = Supervisor.which_children(context[:sup_pid])
    storage_pid = Process.whereis(Storage)

    assert is_pid(context[:sup_pid])
    assert length(children) == 2
    assert is_pid(storage_pid)
    assert children |> List.last == {Storage, storage_pid, :worker, [Storage]}
  end
end