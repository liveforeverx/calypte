defmodule Calypte.Graph do
  @moduledoc """
  In memory graph
  """

  alias Calypte.{Changeset, Changeset.Change, Utils}
  import Utils

  defstruct id_key: "uid", type_key: "type", out_edges: %{}, nodes: %{}, typed: %{}

  @type node_id :: term
  @type edge_id :: term
  @type node_type :: String.t()
  @type t :: %__MODULE__{
          id_key: String.t(),
          type_key: String.t(),
          out_edges: %{node_id => %{edge_id => %{node_id => true}}},
          nodes: %{node_id => term},
          typed: %{node_type => %{node_id => true}}
        }

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
  Get typed ids
  """
  @spec get_typed(t(), String.t()) :: [String.t()]
  def get_typed(%__MODULE__{typed: typed} = _graph, type), do: Map.keys(typed[type] || %{})

  @doc """
  Get node
  """
  @spec get_node(t(), node_id) :: node | nil
  def get_node(%__MODULE__{nodes: nodes}, id), do: Map.get(nodes, id)

  @doc """
  Update graph using changeset
  """
  def add_change(%__MODULE__{} = graph, %Changeset{changes: changes}) do
    Enum.reduce(changes, graph, &apply_change/2)
  end

  defp apply_change(%Change{action: :add, type: :node, id: id, values: attributes}, graph) do
    %__MODULE__{type_key: type_key, nodes: nodes, typed: typed} = graph
    new_node = nodes |> Map.get(id, %{}) |> Map.merge(attributes)

    %__MODULE__{
      graph
      | nodes: Map.put(nodes, id, new_node),
        typed: add_types(typed, id, attributes[type_key])
    }
  end

  defp apply_change(%Change{action: :delete, type: :node, id: id, values: attributes}, graph) do
    %__MODULE__{type_key: type_key, nodes: nodes, typed: types} = graph

    case attributes do
      nil ->
        {node_to_delete, updated_nodes} = Map.pop(nodes, id)
        typed = del_types(types, id, node_to_delete[type_key])
        %__MODULE__{graph | nodes: updated_nodes, typed: typed}

      _ ->
        # TODO:
        graph
    end
  end

  defp apply_change(%Change{action: :add, type: :edge, id: edge_spec, values: timestamp}, graph) do
    %__MODULE__{out_edges: out_edges} = graph
    %__MODULE__{graph | out_edges: deep_put(out_edges, edge_spec, timestamp)}
  end

  defp add_types(typed, id, new_types) do
    types_to_add = List.wrap(new_types)
    Enum.reduce(types_to_add, typed, &deep_put(&2, [from_value(&1), id], true))
  end

  defp del_types(typed, id, removed_types) do
    types_to_remove = List.wrap(removed_types)

    Enum.reduce(types_to_remove, typed, fn type, typed ->
      {_, updated_typed} = Map.get_and_update(typed, from_value(type), &del_type(&1, id))
      updated_typed
    end)
  end

  defp del_type(typed, id) do
    typed = Map.delete(typed, id)
    if map_size(typed) == 0, do: :pop, else: {nil, typed}
  end
end
