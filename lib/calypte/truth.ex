defmodule Calypte.Truth do
  @moduledoc """
  Add truth maintainance if a data changes, than reverts rule executions, which were based on
  this data.
  """

  alias Calypte.{Binding, Changeset, Changeset.Change, Context, LogEntry, Rule, Utils}

  import Utils

  @doc """
  Add execution change to tracking system
  """
  def add_exec_change(%Context{var_tracks: var_tracks} = context, binding) do
    %Binding{rule: rule, hash: hash} = binding
    tracked = Binding.materialized_matches(binding)
    rule_id = Rule.id(rule)

    var_tracks =
      Enum.reduce(tracked, var_tracks, fn {{_var, uid}, attrs}, var_tracks ->
        Enum.reduce(attrs, var_tracks, &update_values(&2, uid, &1, {rule_id, hash}))
      end)

    %Context{context | var_tracks: var_tracks}
  end

  defp update_values(var_tracks, uid, {attr, values}, change_id) do
    values |> List.wrap() |> Enum.reduce(var_tracks, &update_value(&2, uid, attr, &1, change_id))
  end

  defp update_value(var_tracks, uid, attr, value, change_id) do
    triggered_changes = var_tracks[uid][attr][value] || []
    deep_put(var_tracks, [uid, attr, value], [change_id | triggered_changes])
  end

  @doc """
  Add change to tracking system, which can trigger revert of rules, which depends on previous changes
  """
  def add_change(context, changeset) do
    changeset |> traverse_execs(:delete, %{}, context) |> delete_execs(context)
  end

  defp delete_execs(execs, context) do
    execs
    |> Enum.sort(fn {_, id1}, {_, id2} -> id1 >= id2 end)
    |> Enum.reduce(context, &del_exec/2)
  end

  defp traverse_execs(changeset, action, planned, %Context{var_tracks: var_tracks} = context) do
    %Changeset{changes: changes} = changeset
    deletes = gather(changes, action, %{})
    execs = find_execs(deletes, var_tracks)
    execs |> MapSet.to_list() |> tree_traversal(planned, context)
  end

  defp tree_traversal([], planned, _context), do: planned

  defp tree_traversal([{rule_id, hash} | execs], planned, %{exec_store: exec_store} = context) do
    if planned[{rule_id, hash}] do
      tree_traversal(execs, planned, context)
    else
      %{id: id, changeset: changeset, in_state: in_state?} = exec_store[rule_id][hash]

      if in_state? do
        planned = Map.put(planned, {rule_id, hash}, id)
        planned = traverse_execs(changeset, :add, planned, context)
        tree_traversal(execs, planned, context)
      else
        tree_traversal(execs, planned, context)
      end
    end
  end

  defp gather([%Change{type: :node, id: id} = change | changes], action, gathered) do
    %{^action => values} = change

    node_gathered =
      Enum.reduce(values, gathered[id] || %{}, fn {attr, values}, node_gathered ->
        attr_gathered = node_gathered[attr] || %{}

        attr_gathered =
          values |> List.wrap() |> Enum.reduce(attr_gathered, &Map.put(&2, &1, true))

        Map.put(node_gathered, attr, attr_gathered)
      end)

    gathered = Map.put(gathered, id, node_gathered)
    gather(changes, action, gathered)
  end

  defp gather([_ | changes], action, gathered), do: gather(changes, action, gathered)
  defp gather([], _action, gathered), do: gathered

  defp find_execs(deletes, var_tracks) do
    for {id, attrs} <- deletes,
        {attr, values} <- attrs,
        {value, _} <- values,
        reduce: MapSet.new() do
      execs ->
        Enum.reduce(var_tracks[id][attr][value] || [], execs, &MapSet.put(&2, &1))
    end
  end

  defp del_exec({exec_id, _}, context), do: Calypte.del_exec(context, exec_id)

  @doc """
  Delete rule executions
  """
  def delete_rule_execs(context, rule_ids) do
    context |> find_rule_execs(rule_ids) |> tree_traversal(%{}, context) |> delete_execs(context)
  end

  defp find_rule_execs(context, rule_ids) do
    %Context{exec_log: exec_log, exec_store: exec_store} = context

    for %LogEntry{tag: :exec, rule_id: rule_id, change: hash} <- exec_log,
        rule_id in rule_ids,
        %{in_state: in_state?} = exec_store[rule_id][hash],
        in_state? do
      {rule_id, hash}
    end
  end
end
