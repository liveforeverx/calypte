defmodule Calypte.Engine.NaiveVars do
  @moduledoc """
  Implements naive algorithm for finding applicable rules, which understands changesets to
  not check some rules.
  """

  alias Calypte.{Binding, Rule, Utils, Vars}
  alias Calypte.Engine.NaiveFirst
  import Utils

  @behaviour Calypte.Engine

  defstruct executed: %{}, rules: [], plan: [], search: nil, changes: %{}, new_rules: []

  @impl true
  def init(_graph), do: %__MODULE__{}

  @impl true
  def add_rules(%{rules: rules, new_rules: old_new_rules} = state, new_rules) do
    %{state | rules: new_rules ++ rules, new_rules: new_rules ++ old_new_rules}
  end

  @impl true
  def delete_rules(%{rules: rules} = state, rule_ids) do
    %{state | rules: Enum.filter(rules, &(not (Rule.id(&1) in rule_ids)))}
  end

  @impl true
  def add_exec_change(%{executed: executed} = state, {rule_id, hash}, changeset) do
    add_change(%{state | executed: deep_put(executed, [rule_id, hash], true)}, changeset)
  end

  @impl true
  def del_exec_change(%{executed: executed} = state, {rule_id, hash}, changeset) do
    %{^hash => true} = rule_execs = executed[rule_id]

    executed =
      cond do
        map_size(rule_execs) == 1 -> Map.delete(executed, rule_id)
        true -> executed |> pop_in([rule_id, hash]) |> elem(1)
      end

    add_change(%{state | executed: executed}, changeset)
  end

  @impl true
  def add_change(%{changes: changes} = state, changeset),
    do: %{state | changes: Vars.from_changeset(changeset, changes)}

  @impl true
  def eval(%{plan: rules, search: search} = state, graph) do
    search_graph = restrict_graph(graph, search)
    search(rules, search_graph, graph, state)
  end

  defp restrict_graph(graph, _), do: graph

  defp restrict_graph(%{typed: typed} = graph, pattern) do
    typed =
      Enum.reduce(pattern, typed, fn {key, ids}, typed ->
        type_ids = for id <- MapSet.to_list(ids), into: %{}, do: {id, true}
        Map.put(typed, key, type_ids)
      end)

    %{graph | typed: typed}
  end

  def search([], _, graph, %{rules: rules, new_rules: new_rules, changes: changes} = state) do
    cond do
      length(new_rules) > 0 ->
        eval(%{state | plan: new_rules, new_rules: [], search: nil}, graph)

      map_size(changes) > 0 ->
        filtered_rules = Enum.filter(rules, &Vars.in_pattern?(changes, &1.vars["if"]))

        search_pattern = for {type, %{ids: ids}} <- changes, do: {type, ids}
        eval(%{state | plan: filtered_rules, search: search_pattern, changes: %{}}, graph)

      true ->
        {[], state}
    end
  end

  def search([%Rule{if: if_ast} = rule | plan], search_graph, graph, state) do
    case NaiveFirst.find_binding(if_ast, search_graph, Binding.init(graph, rule), state) do
      [] -> search(plan, search_graph, graph, state)
      [binding] -> {[binding], %{state | plan: [rule | plan]}}
    end
  end
end
