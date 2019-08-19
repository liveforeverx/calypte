defmodule Calypte.Context do
  @moduledoc """
  Runtime context, which is needed to run evaluation
  """
  alias Calypte.Graph

  defstruct graph: %Graph{},
            engine: nil,
            state: nil,
            life_cycle: [],
            exec_count: 0,
            exec_log: [],
            exec_store: %{},
            executed?: false,
            last_binding: nil,
            var_tracks: %{}

  @doc """
  Accessor, which forwards access requests to underlying graph
  """
  def fetch(%__MODULE__{graph: graph}, id), do: Access.fetch(graph, id)
end
