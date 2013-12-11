defmodule FilterRouterTest do
  use Funnel.TestCase, async: true
  use Dynamo.HTTP.Case

  @endpoint FilterRouter

  test "returns 400 when an empty body is given" do
    conn = post("/")
    assert conn.status == 400
  end

  test "returns 400 when an empty body is given on put" do
    conn = put("/uuid")
    assert conn.status == 400
  end

  test "returns json when an empty body is given" do
    body = '{"query" : {"term" : {"field1" : "value1"}}}'
    conn = conn(:POST, "/", body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = post(conn, "/")
    assert conn.resp_headers["Content-Type"] == "application/json"
  end

  test "returns 201" do
    body = '{"query" : {"term" : {"field1" : "value1"}}}'
    conn = conn(:POST, "/", body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = post(conn, "/")
    assert conn.status == 201
  end

  test "returns 200" do
    body = '{"query" : {"term" : {"field1" : "value1"}}}'
    conn = conn(:POST, "/", body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = post(conn, "/")
    assert conn.status == 201
    {:ok, body} = JSEX.decode conn.resp_body
    uuid = body["filter_id"]
    body = '{"query" : {"term" : {"field1" : "value2"}}}'
    conn = conn(:PUT, uuid, body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = put(conn, uuid)
    assert conn.status == 200
    Funnel.Es.unpercolate(uuid)
  end

  test "returns json" do
    body = '{"query" : {"term" : {"field1" : "value1"}}}'
    conn = conn(:POST, "/", body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = post(conn, "/")
    assert conn.resp_headers["Content-Type"] == "application/json"
  end

  test "returns a filter_id" do
    body = '{"query" : {"term" : {"field1" : "value1"}}}'
    conn = conn(:POST, "/", body)
    conn = conn.put_req_header "Content-Type", "application/json"
    conn = post(conn, "/")
    {:ok, body} = JSEX.decode conn.resp_body
    assert size(body["filter_id"]) == 36
  end
end