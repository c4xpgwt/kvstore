defmodule Storage do
  @behaviour Storage.Behaviour
  use GenServer

  @table_name   Application.get_env(:kvstore, :tab_name)

  defmodule Behaviour  do
    @callback get_all() :: list(tuple())
    @callback get(key) :: :none | tuple() when key: String.t()
    @callback add(key, value, ttl) :: :ok | :already_exists when key: String.t(), value: String.t(), ttl: integer
    @callback delete(key) :: :ok | :none when key: String.t()
    @callback update(key, value) :: :ok | :none when key: String.t(), value: String.t()
    @callback set_ttl(key, ttl) :: :ok | :none when key: String.t(), ttl: integer
    @callback get_ttl(key) :: integer | :none when key: String.t()
  end

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec get_all() :: list(tuple)
  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  @spec get(key) :: :none | tuple() when key: String.t()
  def get(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def get(_key) do
    raise_argument_error()
  end

  @spec add(key, value, ttl) :: :ok | :already_exists when key: String.t(), value: String.t(), ttl: integer
  def add(key, value, ttl) when is_binary(key) and is_binary(value) and is_integer(ttl) and ttl > 0 do
    GenServer.call(__MODULE__, {:add, {key, value, ttl}})
  end

  def add(_key, _value, _ttl) do
    raise_argument_error()
  end

  @spec delete(key) :: :ok | :none when key: String.t()
  def delete(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:delete, key})
  end

  def delete(_key) do
    raise_argument_error()
  end

  @spec update(key, value) :: :ok | :none when key: String.t(), value: String.t()
  def update(key, value) when is_binary(key) and is_binary(value) do
    GenServer.call(__MODULE__, {:update, {key, value}})
  end

  def update(_key, _value) do
    raise_argument_error()
  end

  @spec set_ttl(key, ttl) :: :ok | :none when key: String.t(), ttl: integer
  def set_ttl(key, ttl) when is_binary(key) and is_integer(ttl) and ttl > 0 do
    GenServer.call(__MODULE__, {:set_ttl, {key, ttl}})
  end

  def set_ttl(_key, _ttl) do
    raise_argument_error()
  end

  @spec get_ttl(key) :: integer | :none when key: String.t()
  def get_ttl(key) when is_binary(key) do
    GenServer.call(__MODULE__, {:get_ttl, key})
  end

  def get_ttl(_key) do
    raise_argument_error()
  end


  ## Server API

  def init(_opts) do
    Process.flag(:trap_exit, true)
    :dets.open_file(@table_name, [type: :set])
    :ets.new(:expiry_time_store, [:ordered_set, :private, :named_table])

    current_time = :erlang.system_time(:second)
    :dets.select_delete(@table_name, [{{:_, :_, :"$1"}, [{:<, :"$1", current_time}], [true]}])

    for [key, time] <- :dets.match(@table_name, {:"$1", :_, :"$2"}) do
      case :ets.lookup(:expiry_time_store, time) do
        [] -> :ets.insert(:expiry_time_store, {time, MapSet.new() |> MapSet.put(key)})
        list -> {_, keys} = (list |> hd)
                :ets.insert(:expiry_time_store, {time, MapSet.put(keys, key)})
      end
    end

    {:ok, update_expiry_timer(nil, nil)}
  end

  def handle_call(:get_all, _from, state) do
    current_time = :erlang.system_time(:second)
    items = :dets.select(@table_name, [{{:"$1", :"$2", :"$3"}, [{:">", :"$3", current_time}], [{{:"$1", :"$2", :"$3"}}]}])
    reply = for {key, value, expiry_time} <- items do {key, value, expiry_time - current_time} end
    {:reply, reply, state}
  end

  def handle_call({:get, key}, _from, state) do
    reply = case :dets.lookup(@table_name, key) do
      [] -> :none
      list ->
        {key, value, expiry_time} = list |> hd
        current_time = :erlang.system_time(:second)
        if current_time < expiry_time do
          {key, value, expiry_time - current_time}
        else
          :none
        end
    end

    {:reply, reply, state}
  end

  def handle_call({:add, {key, value, ttl}}, _from, {ref, next_expiry_time} = state) do
    {reply, state} = case :dets.lookup(@table_name, key) do
      [] ->
        expiry_time = :erlang.system_time(:second) + ttl
        :dets.insert(@table_name, {key, value, expiry_time})
        add_key_to_expiry_time_store(expiry_time, key)

        state = if expiry_time < next_expiry_time do
          update_expiry_timer(ref, next_expiry_time)
        else
          state
        end

        {:ok, state}

      _ -> {:already_exists, state}
    end

    {:reply, reply, state}
  end

  def handle_call({:update, {key, value}}, _from, state) do
    reply = case :dets.lookup(@table_name, key) do
      [] -> :none
      list ->
        {_, _, expiry_time} = list |> hd
        if :erlang.system_time(:second) < expiry_time do
          :dets.insert(@table_name, {key, value, expiry_time})
          :ok
        else
          :none
        end
    end

    {:reply, reply, state}
  end

  def handle_call({:delete, key}, _from, {ref, next_expiry_time} = state) do
    {reply, state} = case :dets.lookup(@table_name, key) do
      [] -> {:none, state}
      list ->
        :dets.delete(@table_name, key)
        {_, _, expiry_time} = list |> hd
        delete_key_from_expiry_time_store(expiry_time, key)

        state = if expiry_time == next_expiry_time do
          update_expiry_timer(ref, next_expiry_time)
        else
          state
        end

        {:ok, state}
    end

    {:reply, reply, state}
  end

  def handle_call({:set_ttl, {key, ttl}}, _from, {ref, next_expiry_time} = state) do
    {reply, state} =
      case :dets.lookup(@table_name, key) do
        [] -> {:none, state}
        list ->
          {_, value, old_expiry_time} = list |> hd
          new_expiry_time = :erlang.system_time(:second) + ttl

          new_state =
            if old_expiry_time == new_expiry_time do
              state
            else
              :dets.insert(@table_name, {key, value, new_expiry_time})

              delete_key_from_expiry_time_store(old_expiry_time, key)
              add_key_to_expiry_time_store(new_expiry_time, key)

              if new_expiry_time < next_expiry_time || old_expiry_time == next_expiry_time do
                update_expiry_timer(ref, next_expiry_time)
              else
                state
              end
            end

          {:ok, new_state}
    end

    {:reply, reply, state}
  end

  def handle_call({:get_ttl, key}, _from, state) do
    reply = case :dets.lookup(@table_name, key) do
      [] -> :none
      list -> {_, _, expiry_time} = list |> hd
              current_time = :erlang.system_time(:second)
              if expiry_time <= current_time do :none else expiry_time - current_time end
    end

    {:reply, reply, state}
  end

  def handle_info(:delete_expired_keys, _state) do
    delete_expired_keys()
    {:noreply, update_expiry_timer(nil, nil)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state) do
    :dets.close(@table_name)
  end

  defp delete_expired_keys() do
    next_time = :ets.first(:expiry_time_store)
    current_time = :erlang.system_time(:second)

    if next_time != :"$end_of_table" and current_time >= next_time do
      {_, keys} = :ets.lookup(:expiry_time_store, next_time) |> hd
      for key <- MapSet.to_list(keys) do
        :dets.delete(@table_name, key)
      end

      :ets.delete(:expiry_time_store, next_time)

      delete_expired_keys()
    end
  end

  defp update_expiry_timer(ref, expiry_time) do
    case :ets.first(:expiry_time_store) do
      :"$end_of_table" ->
        if ref != nil do Process.cancel_timer(ref) end
        {nil, nil}
      time ->
        if time == expiry_time do
          {ref, expiry_time}
        else
          current_time = :erlang.system_time(:second)
          timeout = if time < current_time do 0 else time - current_time end
          {Process.send_after(__MODULE__, :delete_expired_keys, timeout * 1000), time}
        end
    end
  end

  defp add_key_to_expiry_time_store(time, key) do
    case :ets.lookup(:expiry_time_store, time) do
      [] -> :ets.insert(:expiry_time_store, {time, MapSet.new() |> MapSet.put(key)})
      list -> {_, keys} = list |> hd
              :ets.insert(:expiry_time_store, {time, MapSet.put(keys, key)})
    end
  end

  defp delete_key_from_expiry_time_store(time, key) do
    list = :ets.lookup(:expiry_time_store, time)
    if list != [] do
      {_, keys} = list |> hd
      if MapSet.size(keys) < 2 do
        :ets.delete(:expiry_time_store, time)
      else
        :ets.insert(:expiry_time_store, keys |> MapSet.delete(key))
      end
    end
  end

  defp raise_argument_error() do
    raise ArgumentError, "The argument value is invalid"
  end

end