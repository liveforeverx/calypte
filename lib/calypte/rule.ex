defmodule Calypte.Rule do
  @moduledoc """
  Execution of a rule. Works as interpreter at the moment.
  """

  alias Calypte.Ast.{Expr, Var, Value}
  alias Calypte.{Binding, Changeset, Rule, Utils}
  import Utils

  @type id :: term()
  @type exec_id :: {id(), Binding.hash()}

  defstruct id: nil, if: nil, then: nil, meta: %{}, modified_vars: %{}

  @math_operations [:+, :-, :*, :/]
  @comparisons [:>, :>=, :<, :<=, :==]

  def id(%__MODULE__{id: id}), do: id

  @doc """
  Evaluate expression
  """
  def eval(expr_list, binding) when is_list(expr_list) do
    expr_list |> eval_list(binding) |> List.flatten()
  end

  def eval(expr, binding) do
    eval_one(expr, binding)
  end

  def eval_list([], binding), do: binding

  def eval_list([expr | expr_list], binding) do
    for binding <- eval_one(expr, binding), do: eval_list(expr_list, binding)
  end

  def eval_one(expr, %Binding{matches: matches, nodes: nodes} = binding) do
    for values <- do_eval(expr, matches, nodes), values != [] do
      new_matches = values |> List.wrap() |> Enum.reduce(matches, &update_matches/2)
      %Binding{binding | matches: new_matches}
    end
  end

  defp do_eval(%Expr{type: type, left: left, right: right}, matches, nodes)
       when type in @math_operations do
    for left_value <- do_eval(left, matches, nodes),
        right_value <- do_eval(right, matches, nodes) do
      apply_expr(type, unwrap_value(left_value), unwrap_value(right_value))
    end
  end

  defp do_eval(%Expr{type: :=, left: %Var{name: name, attr: attr}} = expr, matches, nodes) do
    %Expr{right: right} = expr

    for right_value <- do_eval(right, matches, nodes),
        do: {{name, attr}, to_value(right_value)}
  end

  defp do_eval(%Expr{type: :default, left: left, right: right}, matches, nodes) do
    with [] <- do_eval(left, matches, nodes) do
      %Var{name: name, attr: attr} = left

      for right_value <- do_eval(right, matches, nodes),
          do: {{name, attr}, to_value(right_value, true)}
    end
  end

  defp do_eval(%Expr{type: type, left: left, right: right} = _expr, matches, nodes)
       when type in @comparisons do
    for left_value <- do_eval(left, matches, nodes),
        right_value <- do_eval(right, matches, nodes) do
      if apply_expr(type, unwrap_value(left_value), unwrap_value(right_value)),
        do: [left_value, right_value],
        else: []
    end
  end

  defp do_eval(%Var{name: name, attr: attr}, matches, nodes) do
    attributes = matches[name][attr] || nodes[name][attr]
    for value <- List.wrap(attributes), do: {{name, attr}, value}
  end

  defp do_eval(%Value{val: value}, _, _nodes), do: [from_value(value)]

  defp unwrap_value({{_, _}, value}), do: from_value(value)
  defp unwrap_value(value), do: value

  for operator <- @comparisons ++ @math_operations do
    defp apply_expr(unquote(operator), left, right), do: unquote(operator)(left, right)
  end

  def update_matches({{name, attr}, value}, matches), do: deep_put(matches, [name, attr], value)
  def update_matches(_, matches), do: matches

  @doc """
  Execute binding
  """
  def exec(%Binding{rule: %Rule{then: then}, matches: old_matches} = binding) do
    %Binding{matches: matches} =
      new_binding =
      Enum.reduce(then, binding, fn expr, binding ->
        [binding] = eval(expr, binding)
        binding
      end)

    new_binding = %{new_binding | matches: old_matches, updated_matches: matches}

    {new_binding, Changeset.from_binding(new_binding)}
  end

  @doc """
  Check if attribute will be modified or not by rule
  """
  def modified_var?(%__MODULE__{modified_vars: modified_vars}, var, attr) do
    with nil <- modified_vars[var][attr], do: false
  end
end
