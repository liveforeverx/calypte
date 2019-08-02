defmodule Calypte.Context do
  @moduledoc """
  Runtime context, which is needed to run evaluation
  """
  alias Calypte.Graph

  defstruct graph: Graph.new(),
            engine: nil,
            state: nil,
            life_cycle: [],
            exec_log: [],
            executed?: false
end
