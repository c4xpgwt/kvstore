defmodule RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts     Router.init([])
  @storage  Application.get_env(:kvstore, :storage)

  test "get all items" do
    conn = conn(:get, "/", "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_list(body)
    assert (for it <- body do {it["key"], it["value"], it["ttl"]} end) == @storage.get_all
  end

  test "get existing item" do
    key = "a"
    conn = conn(:get, "/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert {body["key"], body["value"], body["ttl"]} == @storage.get(key)
  end

  test "get not existing item" do
    key = "b"
    conn = conn(:get, "/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 404
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "get ttl for existing item" do
    key = "a"
    conn = conn(:get, "/get_ttl/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert body["ttl"] == @storage.get_ttl(key)
  end

  test "get ttl for not existing item" do
    key = "b"
    conn = conn(:get, "/get_ttl/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 404
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "add new item" do
    key = "b"
    body_params = Jason.encode!(%{"key" => key, "value" => "value", "ttl" => 100})
    conn = conn(:post, "/", body_params) |> put_req_header("content-type", "application/json") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert Map.has_key?(body, "result")
  end

  test "add new item with wrong ttl" do
    key = "b"
    body_params = Jason.encode!(%{"key" => key, "value" => "value", "ttl" => -100})
    conn = conn(:post, "/", body_params) |> put_req_header("content-type", "application/json") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "add new item with wrong value" do
    key = "b"
    body_params = Jason.encode!(%{"key" => key, "value" => 100, "ttl" => 100})
    conn = conn(:post, "/", body_params) |> put_req_header("content-type", "application/json") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "add item with existing key" do
    key = "a"
    body_params = Jason.encode!(%{"key" => key, "value" => "value", "ttl" => 100})
    conn = conn(:post, "/", body_params) |> put_req_header("content-type", "application/json") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "update existing item" do
    key = "a"
    body_params = Jason.encode!(%{"value" => "value"})
    conn = conn(:post, "/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert Map.has_key?(body, "result")
  end

  test "update existing item with wrong value" do
    key = "a"
    body_params = Jason.encode!(%{"value" => 100})
    conn = conn(:post, "/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "update not existing item" do
    key = "b"
    body_params = Jason.encode!(%{"value" => "value"})
    conn = conn(:post, "/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 404
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "delete existing item" do
    key = "a"
    conn = conn(:delete, "/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert Map.has_key?(body, "result")
  end

  test "delete not existing item" do
    key = "b"
    conn = conn(:delete, "/" <> key, "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 404
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "set ttl for existing item" do
    key = "a"
    body_params = Jason.encode!(%{"ttl" => 100})
    conn = conn(:post, "/set_ttl/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 200
    assert is_map(body)
    assert Map.has_key?(body, "result")
  end

  test "set ttl for existing item with wrong ttl" do
    key = "a"
    body_params = Jason.encode!(%{"ttl" => "100"})
    conn = conn(:post, "/set_ttl/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "set ttl for not existing item" do
    key = "b"
    body_params = Jason.encode!(%{"ttl" => 100})
    conn = conn(:post, "/set_ttl/" <> key, body_params)
           |> put_req_header("content-type", "application/json")
           |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 404
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

  test "send bad request" do
    conn = conn(:get, "/none/none", "") |> Router.call(@opts)
    body = Jason.decode!(conn.resp_body)

    assert conn.status == 400
    assert is_map(body)
    assert Map.has_key?(body, "message")
  end

end