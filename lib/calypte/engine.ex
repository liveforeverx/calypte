defmodule Calypte.Engine do
  @moduledoc """
  Algorithm behaviour for a pluggable algorithm.

  As the execution part has many parts in common and there are different operations happening in
  common and that algorithm doesn't bother with this things, the selection and execution parts are
  separated from `Engine` implementation. `Engine` implementation shouldn't bother with this parts.

    Engine.eval -> {possible_bindings, state} # return possible next steps

    Core.select  # selecting next rule to execute, there can be different selection strategies used
    Core.execute # execute the rule and do anything what is needed, logging and executing any related
                 # callbacks

    Engine.exec(binding, changeset) # notify engine back about selected and executed binding

  Exec and add_change steps are separated, because there can be changes comming from another
  sources, which are not comming from execution. So `exec` callback should mark for own algorithm,
  that this rule was already executed and changes should be applied by `add_change` callback, which
  happens afterwards. This architecture allows to implement engine only the algorithm and core
  takes care for auditing and other features, which should be executed before or after execution.
  """

  alias Calypte.{Binding, Changeset, Graph, Rule}

  @type state :: any

  @callback init(Graph.t()) :: state

  @callback add_rules(state, [Rule.t()]) :: state
  @callback add_change(state, Changeset.t()) :: state

  @callback eval(state, Graph.t()) :: {[Binding.t()], state}
  @callback add_exec_change(state, Rule.exec_id(), Changeset.t()) :: state
  @callback del_exec_change(state, Rule.exec_id(), Changeset.t()) :: state

  def init(module, graph), do: module.init(graph)
  def add_rules(module, state, rules), do: module.add_rules(state, rules)
  def eval(module, state, graph), do: module.eval(state, graph)

  def add_change(module, state, changeset), do: module.add_change(state, changeset)

  def add_exec_change(module, state, exec_id, changeset),
    do: module.add_exec_change(state, exec_id, changeset)

  def del_exec_change(module, state, exec_id, changeset),
    do: module.add_exec_change(state, exec_id, changeset)
end
