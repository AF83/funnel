defmodule Funnel.Percolator do
  @moduledoc """
  `Funnel.Percolator` is meant to receive documents, send those documents to the
  Elasticsearch percolation, then, notify each User.
  """

  use GenServer.Behaviour

  @doc """

  Start a new `Funnel.Percolator` actor.
  """
  def start_link(_state) do
    :gen_server.start_link(__MODULE__, nil, [])
  end

  @doc """

  Wrapper around `GenServer`. Send a document to Elasticsearch's percolator.

  * `body`     - Document in json
  """
  def percolate(percolator, index_id, body) do
    :gen_server.cast percolator, {:percolate, index_id, body}
  end

  @doc """

  Default values of `Funnel.Percolator`.
  """
  def init do
    {:ok, nil}
  end

  @doc """

  Percolates and notify on each match.
  """
  def handle_cast({:percolate, index_id, body}, nil) do
    Funnel.Es.percolate(index_id, body)
      |> group_by_token
      |> Enum.each(fn(match)-> notify(match, body) end)
    { :noreply, nil}
  end

  defp group_by_token(collection) do
    Enum.reduce(collection, [], fn(match, matches) ->
      [token, uuid] = decode_match(match)
      match = extract_match(matches, token)
      ids = [uuid | match[:query_ids]]
      matches = List.delete(matches, match)

      [%{match | :query_ids => ids} | matches]
    end)
  end

  defp extract_match(matches, token) do
    case Enum.find(matches, fn(x) -> x[:token] == token end) do
      nil  -> %{:token => token, :query_ids => []}
      elem -> elem
    end
  end

  defp notify(match, body) do
    token = match[:token]
    id = Funnel.Uuid.generate

    {:ok, cache} = Funnel.Caches.add token
    {:ok, response} = JSEX.encode([query_ids: match[:query_ids], body: body])

    Funnel.Transistor.Cache.push(cache, id, response)
    Funnel.Transistor.notify(token, id, response)
  end

  defp decode_match(match) do
    String.split(match["_id"], "-")
  end
end
