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
            var_tracks: %{}
end
