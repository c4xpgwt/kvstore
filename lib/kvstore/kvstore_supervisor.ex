defmodule KVStore.Supervisor do
  use Supervisor

  @default_port   8080

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    port = Application.get_env(:kvstore, :port, @default_port)

    children = [
      worker(Storage, []),
      Plug.Adapters.Cowboy.child_spec(:http, Router, [], port: port)
    ]

    supervise(children, strategy: :rest_for_one)
  end
end