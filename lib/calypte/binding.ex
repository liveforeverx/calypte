defmodule Calypte.Binding do
  @moduledoc """

  """

  alias Calypte.{Rule, Utils}

  import Utils

  defstruct rule: nil, id_key: nil, matches: %{}, nodes: %{}

  def hash(%__MODULE__{rule: rule, matches: matches} = binding) do
    bindings_with_ids =
      for {var, bindings} <- matches, into: %{}, do: {{var, node_id!(binding, var)}, bindings}

    :erlang.phash2({Rule.id(rule), bindings_with_ids})
  end

  def node_id!(%__MODULE__{id_key: id_key, nodes: nodes}, var),
    do: nodes |> Map.fetch!(var) |> Map.fetch!(id_key) |> from_value()
end
