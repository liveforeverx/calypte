defmodule Calypte.Graph do
  @moduledoc """
  In memory graph
  """

  alias Calypte.{Changeset, Changeset.Change, Utils}
  import Utils

  @type node_id :: term
  @type edge_type :: term
  @type edge_id :: {node_id, edge_type, node_id}
  @type node_type :: String.t()
  @type t :: %__MODULE__{
          id_key: String.t(),
          type_key: String.t(),
          out_edges: %{node_id => %{edge_type => %{node_id => true}}},
          nodes: %{node_id => term},
          edges: %{edge_id => term},
          typed: %{node_type => %{node_id => true}}
        }

  defstruct id_key: "uid", type_key: "type", out_edges: %{}, nodes: %{}, edges: %{}, typed: %{}

  @doc """
  Create new graph
  """
  @spec new(String.t(), map()) :: t()
  def new(json \\ %{}, opts \\ []) do
    graph = %__MODULE__{id_key: opts[:id_key] || "uid", type_key: opts[:type_key] || "type"}
    changeset = Changeset.from_json(graph, json)
    add_change(graph, changeset)
  end

  @doc """
  Get typed ids. If list ids provided, than it filtered to contain only this type
  """
  @spec get_typed(t(), String.t()) :: [String.t()]
  def get_typed(%__MODULE__{typed: typed} = _graph, type), do: Map.keys(typed[type] || %{})

  @spec get_typed(t(), String.t(), [node_id]) :: [String.t()]
  def get_typed(%__MODULE__{typed: typed} = _graph, type, ids) do
    type_map = typed[type] || %{}
    Enum.filter(ids, &Map.has_key?(type_map, &1))
  end

  @spec related(t(), String.t(), String.t()) :: [String.t()]
  def related(%__MODULE__{out_edges: out_edges, id_key: id_key} = _graph, node, edge_type) do
    id = Map.get(node, id_key, []) |> from_value() |> unwrap()
    edges_map = out_edges[id][edge_type] || %{}
    Map.keys(edges_map)
  end

  @doc """
  Get node
  """
  @spec get_node(t(), node_id) :: node | nil
  def get_node(%__MODULE__{nodes: nodes}, id), do: Map.get(nodes, id)

  @spec get_node_type(t(), node_id) :: node_type | nil
  def get_node_type(%__MODULE__{nodes: nodes}, id), do: nodes |> Map.get(id) |> from_value()

  @doc """
  Implements Access protocol for read
  """
  def fetch(%__MODULE__{nodes: nodes}, id), do: Map.fetch(nodes, id)

  @doc """
  Update graph using changeset
  """
  def add_change(%__MODULE__{} = graph, %Changeset{changes: changes}) do
    Enum.reduce(changes, graph, &apply_change/2)
  end

  defp apply_change(%Change{type: :node, id: id, delete: delete, add: add}, graph) do
    %__MODULE__{type_key: type_key, nodes: nodes, typed: typed} = graph
    nodes = update_attributes(nodes, id, delete, add)
    delete_types = Map.get(delete, type_key)
    add_types = Map.get(add, type_key)
    typed = update_types(typed, id, delete_types, add_types)
    %__MODULE__{graph | nodes: nodes, typed: typed}
  end

  defp apply_change(%Change{type: :edge, id: edge_id, delete: delete, add: add}, graph) do
    %__MODULE__{edges: edges, out_edges: out_edges} = graph
    edges = update_attributes(edges, edge_id, delete, add)
    {from_id, edge, to_id} = edge_id
    out_edges = deep_put(out_edges, [from_id, edge, to_id], true)
    %__MODULE__{graph | out_edges: out_edges, edges: edges}
  end

  defp update_attributes(container, id, delete, add) do
    entity = Map.get(container, id, %{})

    case do_update_attributes(entity, delete, add) do
      new_entity when map_size(new_entity) == 0 -> Map.delete(container, id)
      new_entity -> Map.put(container, id, new_entity)
    end
  end

  defp do_update_attributes(entity, delete, add) do
    {entity, delete} =
      Enum.reduce(add, {entity, delete}, fn {attr, add_values}, {entity, delete} ->
        {delete_values, delete} = Map.pop(delete, attr)
        {update_attr(entity, attr, delete_values, add_values), delete}
      end)

    Enum.reduce(delete, entity, fn {attr, values}, entity ->
      update_attr(entity, attr, values, nil)
    end)
  end

  defp update_attr(entity, attr, delete_values, add_values) do
    existing_values = Map.get(entity, attr)

    case (wrap(existing_values) -- wrap(delete_values)) ++ wrap(add_values) do
      [] -> Map.delete(entity, attr)
      new_values -> Map.put(entity, attr, unwrap(new_values))
    end
  end

  defp update_types(typed, id, delete_types, new_types) do
    typed |> del_types(id, delete_types) |> add_types(id, new_types)
  end

  defp add_types(typed, id, new_types) do
    types_to_add = wrap(new_types)
    Enum.reduce(types_to_add, typed, &deep_put(&2, [from_value(&1), id], true))
  end

  defp del_types(typed, id, deleted_types) do
    deleted_types = wrap(deleted_types)

    Enum.reduce(deleted_types, typed, fn type, typed ->
      {_, updated_typed} = Map.get_and_update(typed, from_value(type), &del_type(&1, id))
      updated_typed
    end)
  end

  defp del_type(typed, id) do
    typed = Map.delete(typed, id)
    if map_size(typed) == 0, do: :pop, else: {nil, typed}
  end

  def to_map(graph, root) do
    {map, _} = to_map(graph, root, [])
    map
  end

  defp to_map(graph, node_ids, visited) when is_list(node_ids) do
    Enum.map_reduce(node_ids, visited, &to_map(graph, &1, &2))
  end

  defp to_map(%{out_edges: out_edges} = graph, node_id, visited) do
    with %{} = node <- get_node(graph, node_id) do
      out_edges = out_edges[node_id] || %{}

      {edges, visited} =
        Enum.map_reduce(out_edges, visited, fn {edge_id, nodes}, visited ->
          child_ids = Map.keys(nodes)
          {childs, visited} = to_map(graph, child_ids, visited)
          {{edge_id, childs}, visited}
        end)

      {Enum.into(edges, node), visited}
    end
  end
end
