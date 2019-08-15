defmodule Calypte.Changeset do
  @moduledoc """
  Structure to represent changes for
  """

  alias Calypte.{Binding, Graph, Value, Utils}
  import Utils

  @type t :: %__MODULE__{changes: []}

  defstruct changes: []

  defmodule Change do
    @type t :: %__MODULE__{
            action: :add | :del,
            type: :edge | :node,
            id: any,
            values: any
          }
    defstruct action: :add, type: :node, id: nil, values: nil
  end

  @doc """
  Build changeset from a json
  """
  def from_json(graph, json) do
    %__MODULE__{changes: graph |> do_build(json) |> List.flatten()}
  end

  def do_build(graph, json) when is_list(json), do: Enum.map(json, &do_build(graph, &1))

  def do_build(%Graph{id_key: id_key} = graph, json) when is_map(json) do
    case json do
      %{^id_key => id} -> build_changes(graph, id, json)
      _ -> []
    end
  end

  def build_changes(graph, id, json) do
    %Graph{id_key: id_key, nodes: nodes} = graph
    {edges, node} = Enum.split_with(json, fn {_, value} -> is_edge(value) end)
    node = for {key, value} <- node, into: %{}, do: {key, [Value.new(value)]}
    old_node = Map.get(nodes, id, %{})
    {add_attrs, delete_attrs} = diff_node(old_node, node)

    nested_jsons = for {_, json} <- edges, do: json

    [
      del_change(id, delete_attrs),
      add_change(id, add_attrs),
      do_build(graph, nested_jsons),
      edge_changes(id, id_key, edges)
    ]
  end

  defp is_edge([%{} | _]), do: true
  defp is_edge(%{}), do: true
  defp is_edge(_), do: false

  defp diff_node(old_node, new_node) do
    Enum.reduce(new_node, {[], []}, fn {key, values}, {add, delete} ->
      old_values = old_node[key]
      to_delete = diff_values(key, old_values, values)
      to_add = diff_values(key, values, old_values)
      {to_add ++ add, to_delete ++ delete}
    end)
  end

  defp diff_values(_key, nil, _existing), do: []
  defp diff_values(key, values, nil), do: key_diff(key, values)

  defp diff_values(key, values, to_diff) do
    to_diff = Enum.map(to_diff, &from_value(&1))
    values = Enum.filter(values, fn value -> not (from_value(value) in to_diff) end)
    key_diff(key, values)
  end

  defp key_diff(_key, []), do: []
  defp key_diff(key, values), do: [{key, values}]

  defp add_change(_id, []), do: []
  defp add_change(id, changes), do: %Change{id: id, values: Map.new(changes)}

  defp del_change(_id, []), do: []
  defp del_change(id, changes), do: %Change{action: :del, id: id, values: Map.new(changes)}

  defp edge_changes(id, id_key, edges) do
    for {edge, jsons} <- edges,
        %{^id_key => in_id} <- List.wrap(jsons),
        do: %Change{type: :edge, id: [id, edge, in_id], values: timestamp()}
  end

  @doc """
  Build changeset from binding diff
  """
  def from_binding(%Binding{matches: old_matches, updated_matches: new_matches} = binding) do
    to_delete = find_new(old_matches, new_matches)
    to_add = find_new(new_matches, old_matches)

    to_delete_changes =
      for {var, attrs} <- to_delete,
          do: %Change{action: :del, id: Binding.node_id!(binding, var), values: attrs}

    to_add_changes =
      for {var, attrs} <- to_add,
          do: %Change{action: :add, id: Binding.node_id!(binding, var), values: attrs}

    %__MODULE__{changes: to_delete_changes ++ to_add_changes}
  end

  defp find_new(matches1, matches2) do
    Enum.reduce(matches1, %{}, fn {var, values}, acc ->
      var_attrs2 = Map.get(matches2, var, %{})
      Enum.reduce(values, acc, &find_new_in_attr(var, &1, var_attrs2, &2))
    end)
  end

  defp find_new_in_attr(var, {attr, values}, var_attrs2, acc) do
    case values |> List.wrap() |> Enum.filter(&(&1.virtual != true)) do
      [] ->
        acc

      values ->
        case List.wrap(var_attrs2[attr]) do
          ^values -> acc
          _ -> deep_put(acc, [var, attr], values)
        end
    end
  end

  @doc """
  Revert changeset
  """
  def revert(%__MODULE__{changes: changes} = changeset) do
    %{changeset | changes: Enum.reduce(changes, [], &[revert_change(&1) | &2])}
  end

  defp revert_change(%Change{action: :del} = change), do: %{change | action: :add}
  defp revert_change(%Change{action: :add} = change), do: %{change | action: :del}
end
