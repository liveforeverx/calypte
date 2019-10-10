defmodule Calypte.Binding do
  @moduledoc """

  """

  alias Calypte.{Graph, Rule, Utils}

  import Utils

  @type hash :: integer()

  defstruct rule: nil,
            id_key: nil,
            type_key: nil,
            hash: nil,
            matches: %{},
            updated_matches: %{},
            nodes: %{},
            types: %{}

  def init(%Graph{id_key: id_key, type_key: type_key} = graph, rule) do
    %__MODULE__{rule: rule, id_key: id_key, type_key: type_key}
  end

  def put_match(%__MODULE__{matches: matches} = binding, name, attr, value) do
    %{binding | matches: deep_put(matches, [name, attr], to_value(value, true))}
  end

  def calc_hash(%__MODULE__{rule: rule} = binding) do
    hashable_matches = materialized_matches(binding, &filter_attributes(rule, &1, &2))
    %__MODULE__{binding | hash: :erlang.phash2({Rule.id(rule), hashable_matches})}
  end

  def hash(%__MODULE__{hash: hash} = _binding) when hash != nil, do: hash

  def materialized_matches(binding, filter \\ fn _var, attributes -> attributes end) do
    %__MODULE__{id_key: id_key, matches: matches, nodes: nodes} = binding

    for {var, attributes} <- matches, into: %{} do
      {{var, node_id!(nodes, id_key, var)}, filter.(var, attributes)}
    end
  end

  defp filter_attributes(rule, var, attributes) do
    for {attr, values} <- attributes, not Rule.modified_var?(rule, var, attr), into: %{} do
      {attr, values}
    end
  end

  def var_info(%__MODULE__{id_key: id_key, type_key: type_key, nodes: nodes}, var) do
    %{^id_key => id, ^type_key => types} = Map.fetch!(nodes, var)
    {from_value(id), types}
  end

  def node_id!(%__MODULE__{id_key: id_key, nodes: nodes}, var), do: node_id!(nodes, id_key, var)

  defp node_id!(nodes, id_key, var) do
    nodes |> Map.fetch!(var) |> Map.fetch!(id_key) |> from_value()
  end
end
