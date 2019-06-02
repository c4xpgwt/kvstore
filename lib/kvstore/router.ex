defmodule Router do
  use Plug.Router

  plug Plug.Parsers, parsers: [:json],
                     pass: ["text/*"],
                     json_decoder: Jason

  plug :match
  plug :dispatch

  @storage    Application.get_env(:kvstore, :storage)

  @item_not_found_message         "Item not found"
  @item_success_added_message     "Item success added"
  @item_success_changed_message   "Item success changed"
  @item_success_deleted_message   "Item success deleted"
  @item_already_exists_message    "Item already exists"
  @ttl_success_changed_message    "TTL success changed"
  @wrong_body_format_message      "Body format incorrect"
  @bad_request_message            "Bad Request"

  get "/" do
    data = for {key, value, ttl} <- @storage.get_all() do %{key: key, value: value, ttl: ttl} end
    render_json(conn, data)
  end

  get "/:key" do
    case @storage.get(key) do
      :none -> render_json(conn, %{message: @item_not_found_message}, 404)
      {key, value, ttl} -> render_json(conn, %{key: key, value: value, ttl: ttl} )
    end
  end

  get "/get_ttl/:key" do
    case @storage.get_ttl(key) do
      :none -> render_json(conn, %{message: @item_not_found_message}, 404)
      value -> render_json(conn, %{ttl: value})
    end
  end

  post "/" do
    case conn.body_params do
      %{"key" => key, "value" => value, "ttl" => ttl} ->
        if Utils.is_valid?(key, value, ttl) do
          case @storage.add(key, value, ttl) do
            :ok -> render_json(conn, %{result: @item_success_added_message})
            :already_exists -> render_json(conn, %{message: @item_already_exists_message}, 400)
          end
        else
          render_json(conn, %{message: @wrong_body_format_message}, 400)
        end
      _ -> render_json(conn, %{message: @wrong_body_format_message}, 400)
    end
  end

  post "/:key" do
    case conn.body_params do
      %{"value" => value} ->
        if Utils.is_valid_value?(value) do
          case @storage.update(key, value) do
            :ok -> render_json(conn, %{result: @item_success_changed_message})
            :none -> render_json(conn, %{message: @item_not_found_message}, 404)
          end
        else
          render_json(conn, %{message: @wrong_body_format_message}, 400)
        end
      _ -> render_json(conn, %{message: @wrong_body_format_message}, 400)
    end
  end

  delete "/:key" do
    case @storage.delete(key) do
      :ok -> render_json(conn, %{result: @item_success_deleted_message})
      :none -> render_json(conn, %{message: @item_not_found_message}, 404)
    end

  end

  post "/set_ttl/:key" do
    case conn.body_params do
      %{"ttl" => ttl} ->
        if Utils.is_valid_ttl?(ttl) do
          case @storage.set_ttl(key, ttl) do
            :ok -> render_json(conn, %{result: @ttl_success_changed_message})
            :none -> render_json(conn, %{message: @item_not_found_message}, 404)
          end
        else
          render_json(conn, %{message: @wrong_body_format_message}, 400)
        end
      _ -> render_json(conn, %{message: @wrong_body_format_message}, 400)
    end
  end

  match _ do
    render_json(conn, %{message: @bad_request_message}, 400)
  end

  defp render_json(conn, data, status \\ 200) do
    body = Jason.encode!(data)
    conn |> put_resp_content_type("application/json") |> send_resp(status, body)
  end
end