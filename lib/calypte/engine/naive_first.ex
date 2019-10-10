defmodule Calypte.Engine.NaiveFirst do
  @moduledoc """
  Implements naive algorithm for finding applicable rules.

  It uses basic tree search first match algorithm for finding applicable node using type optimization.
  """

  alias Calypte.{Binding, Graph, Rule, Utils}
  alias Calypte.Ast.{Relation, Var}
  import Utils

  @behaviour Calypte.Engine

  defstruct executed: %{}, rules: []

  @impl true
  def init(_graph), do: %__MODULE__{}

  @impl true
  def add_rules(%{rules: rules} = state, new_rules), do: %{state | rules: new_rules ++ rules}

  @impl true
  def delete_rules(%{rules: rules} = state, rule_ids) do
    %{state | rules: Enum.filter(rules, &(not (Rule.id(&1) in rule_ids)))}
  end

  @impl true
  def add_exec_change(%{executed: executed} = state, {rule_id, hash}, _) do
    %{state | executed: deep_put(executed, [rule_id, hash], true)}
  end

  @impl true
  def del_exec_change(%{executed: executed} = state, {rule_id, hash}, _) do
    %{^hash => true} = rule_execs = executed[rule_id]

    cond do
      map_size(rule_execs) == 1 -> %{state | executed: Map.delete(executed, rule_id)}
      true -> %{state | executed: executed |> pop_in([rule_id, hash]) |> elem(1)}
    end
  end

  @impl true
  def add_change(state, _), do: state

  @impl true
  def eval(%{rules: rules} = state, graph) do
    {search(rules, graph, state), state}
  end

  def search([], _graph, _state), do: []

  def search([%Rule{if: if_ast} = rule | rules], graph, state) do
    with [] <- find_binding(if_ast, graph, Binding.init(graph, rule), state) do
      search(rules, graph, state)
    end
  end

  @doc """
  Simple find of binding using sequential unfolding of matches
  """
  def find_binding([], _graph, %Binding{} = binding, state) do
    binding = Binding.calc_hash(binding)
    if executed?(state, binding), do: [], else: [binding]
  end

  def find_binding([%Var{name: name, type: type} | matches], graph, binding, state)
      when is_binary(type) do
    candidates = Graph.get_typed(graph, type)
    %{types: types} = binding
    binding = %{binding | types: Map.put(types, name, type)}
    check_branches(name, candidates, matches, graph, binding, state)
  end

  def find_binding([%Relation{} = relation | matches], graph, binding, state) do
    %Relation{from: %Var{name: from_var}, to: %Var{name: to_var, type: type}, edge: edge} =
      relation

    %{nodes: nodes, types: types} = binding
    binding = %{binding | types: Map.put(types, to_var, type)}

    edges = Graph.related(graph, nodes[from_var], edge)
    candidates = Graph.get_typed(graph, type, edges)
    check_branches(to_var, candidates, matches, graph, binding, state)
  end

  def find_binding([expr | matches], graph, binding, state) do
    check_bindings(matches, graph, Rule.match(expr, binding), state)
  end

  def check_branches(_, [], _matches, _graph, _binding, _state), do: []

  def check_branches(name, [candidate | candidates], matches, graph, binding, state) do
    %Binding{nodes: nodes} = binding
    node = Graph.get_node(graph, candidate)
    new_binding = %Binding{binding | nodes: Map.put(nodes, name, node)}

    with [] <- find_binding(matches, graph, new_binding, state),
         do: check_branches(name, candidates, matches, graph, binding, state)
  end

  def check_bindings(_matches, _graph, [], _state), do: []

  def check_bindings(matches, graph, [binding | next_bindings], state) do
    with [] <- find_binding(matches, graph, binding, state),
         do: check_bindings(matches, graph, next_bindings, state)
  end

  def executed?(%{executed: executed} = _state, %Binding{rule: rule, hash: hash}) do
    executed[Rule.id(rule)][hash]
  end
end
