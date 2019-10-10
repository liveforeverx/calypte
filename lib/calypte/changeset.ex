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
            type: :edge | :node,
            id: any,
            delete: nil,
            add: nil,
            meta: any
          }
    defstruct type: :node, id: nil, delete: %{}, add: %{}, meta: nil
  end

  @creation_key :created

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
    %Graph{id_key: id_key, type_key: type_key, nodes: nodes} = graph
    {edges, node} = Enum.split_with(json, fn {_, value} -> is_edge(value) end)

    node = valuefy_node(node)
    {old_node, node} = fetch_or_create(nodes, id, node)
    {delete_attrs, add_attrs} = partial_diff_attrs(old_node, node)

    nested_jsons = for {_, json} <- edges, do: json
    type = from_value(old_node[type_key] || node[type_key])

    [
      %Change{id: id, delete: delete_attrs, add: add_attrs, meta: List.wrap(type)},
      do_build(graph, nested_jsons),
      edge_changes(id, edges, id_key, graph)
    ]
  end

  defp fetch_or_create(container, id, new_entity) do
    case Map.get(container, id) do
      nil -> {%{}, Map.put(new_entity, @creation_key, Utils.timestamp())}
      old_entity -> {old_entity, new_entity}
    end
  end

  defp is_edge([%{} | _]), do: true
  defp is_edge(%{}), do: true
  defp is_edge(_), do: false

  defp valuefy_node(node) do
    for {key, value} <- node, !String.contains?(key, "|"), into: %{}, do: {key, Value.new(value)}
  end

  defp valuefy_edge(node, edge_name) do
    Enum.reduce(node, %{}, fn {key, value}, acc ->
      case String.split(key, "|") do
        [^edge_name, edge_attr] -> Map.put(acc, edge_attr, Value.new(value))
        _ -> acc
      end
    end)
  end

  defp partial_diff_attrs(old_attrs, new_attrs) do
    {delete_attrs, add_attrs} = do_partial_diff(old_attrs, new_attrs)
    {Map.new(delete_attrs), Map.new(add_attrs)}
  end

  defp do_partial_diff(old_attrs, new_attrs) do
    Enum.reduce(new_attrs, {[], []}, fn {key, values}, {delete, add} ->
      values = List.wrap(values)
      old_values = List.wrap(old_attrs[key])
      to_delete = diff_real_values(key, old_values, values)
      to_add = diff_real_values(key, values, old_values)
      {to_delete ++ delete, to_add ++ add}
    end)
  end

  defp diff_real_values(key, values, to_diff) do
    to_diff = Enum.map(to_diff, &from_value(&1))
    values = Enum.filter(values, fn value -> not (from_value(value) in to_diff) end)
    key_diff(key, values)
  end

  defp key_diff(_key, []), do: []
  defp key_diff(key, values), do: [{key, unwrap(values)}]

  defp edge_changes(id, edge_jsons, id_key, %Graph{edges: edges}) do
    for {edge, jsons} <- edge_jsons,
        %{^id_key => in_id} = json <- List.wrap(jsons) do
      edge_id = {id, edge, in_id}

      new_edge = valuefy_edge(json, edge)
      {old_edge, new_edge} = fetch_or_create(edges, edge_id, new_edge)
      {delete_attrs, add_attrs} = partial_diff_attrs(old_edge, new_edge)
      %Change{type: :edge, id: edge_id, delete: delete_attrs, add: add_attrs}
    end
  end

  @doc """
  Build changeset from binding diff
  """
  def from_binding(binding) do
    %Binding{matches: old_matches, updated_matches: new_matches, types: _types} = binding

    changes =
      for {var, {to_delete, to_add}} <- diff_matches(old_matches, new_matches) do
        {id, types} = id_types(binding, var, to_delete, to_add)
        %Change{id: id, delete: to_delete, add: to_add, meta: types}
      end

    %__MODULE__{changes: changes}
  end

  defp id_types(%{type_key: type_key} = binding, var, to_delete, to_add) do
    {id, types} = Binding.var_info(binding, var)
    types = (wrap(types) -- values(to_delete, type_key)) ++ values(to_add, type_key)
    {id, Enum.map(types, &from_value/1)}
  end

  defp values(map, type_key), do: map |> Map.get(type_key) |> wrap()

  defp diff_matches(old_matches, new_matches) do
    {diffs, old_matches} =
      Enum.flat_map_reduce(new_matches, old_matches, fn {var, attrs}, old_matches ->
        {old_attrs, old_matches} = Map.pop(old_matches, var, %{})
        {flat_diff(var, old_attrs, attrs), old_matches}
      end)

    deletes = Enum.flat_map(old_matches, fn {var, values} -> flat_diff(var, values, %{}) end)
    deletes ++ diffs
  end

  defp flat_diff(var, old_attrs, new_attrs) do
    case diff_attrs(old_attrs, new_attrs) do
      {[], []} -> []
      {to_delete, to_add} -> [{var, {Map.new(to_delete), Map.new(to_add)}}]
    end
  end

  defp diff_attrs(old_attrs, new_attrs) do
    {delete, add, old_attrs} =
      Enum.reduce(new_attrs, {[], [], old_attrs}, fn {attr, values}, {delete, add, old_attrs} ->
        {old_values, old_attrs} = Map.pop(old_attrs, attr)
        {to_delete, to_add} = diff_values(attr, old_values, values)
        {to_delete ++ delete, to_add ++ add, old_attrs}
      end)

    to_delete =
      Enum.flat_map(old_attrs, fn {attr, values} -> key_diff(attr, non_virtual(values)) end)

    {to_delete ++ delete, add}
  end

  defp diff_values(attr, old_values, new_values) do
    old_values = old_values |> wrap() |> non_virtual()
    new_values = new_values |> wrap() |> non_virtual()
    {key_diff(attr, old_values -- new_values), key_diff(attr, new_values -- old_values)}
  end

  defp non_virtual(attrs), do: Enum.filter(attrs, &(not match?(%{virtual: true}, &1)))

  @doc """
  Revert changeset
  """
  def revert(%__MODULE__{changes: changes} = changeset) do
    %{changeset | changes: Enum.reduce(changes, [], &[revert_change(&1) | &2])}
  end

  defp revert_change(%Change{delete: delete, add: add} = change),
    do: %{change | delete: add, add: delete}
end
