defmodule Calypte.Engine.NaiveFirst do
  @moduledoc """
  Implements naive algorithm for finding applicable rules.

  It uses basic tree search first match algorithm for finding applicable node using type optimization.
  """

  alias Calypte.{Binding, Graph, Rule, Utils}
  alias Calypte.Ast.{Var}
  import Utils

  @behaviour Calypte.Engine

  defstruct executed: %{}, rules: []

  @impl true
  def init(_graph), do: %__MODULE__{}

  @impl true
  def add_rules(%{rules: rules} = state, new_rules), do: %{state | rules: new_rules ++ rules}

  @impl true
  def eval(%{rules: rules} = state, graph) do
    {search(rules, graph, state), state}
  end

  @impl true
  def add_exec_change(%{executed: executed} = state, _, %Binding{rule: rule} = binding) do
    %{state | executed: deep_put(executed, [Rule.id(rule), Binding.hash(binding)], true)}
  end

  @impl true
  def add_change(state, _), do: state

  def search([], _graph, _state), do: []

  def search([%Rule{if: if_ast} = rule | rules], %{id_key: id_key} = graph, state) do
    with [] <- find_binding(if_ast, graph, %Binding{rule: rule, id_key: id_key}, state) do
      search(rules, graph, state)
    end
  end

  defp find_binding([], _graph, %Binding{} = binding, state) do
    if executed?(state, binding), do: [], else: [binding]
  end

  defp find_binding([%Var{name: name, type: type} | matches], graph, binding, state)
       when is_binary(type) do
    candidates = Graph.get_typed(graph, type)
    check_branches(name, candidates, matches, graph, binding, state)
  end

  defp find_binding([expr | matches], graph, binding, state) do
    check_bindings(matches, graph, Rule.eval(expr, binding), state)
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

  def executed?(%{executed: executed} = _state, %Binding{rule: rule} = binding) do
    executed[Rule.id(rule)][Binding.hash(binding)]
  end
end