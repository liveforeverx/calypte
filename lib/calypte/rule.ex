defmodule Calypte.Rule do
  @moduledoc """
  Execution of a rule. Works as interpreter at the moment.
  """

  alias Calypte.Ast.{Expr, Var, Value}
  alias Calypte.{Binding, Changeset, Rule, Utils}
  import Utils

  defstruct id: nil, if: nil, then: nil, meta: %{}

  @comparisons [:>, :>=, :<, :<=, :==]

  def id(%__MODULE__{id: id}), do: id

  @doc """
  Evaluate expression
  """
  def eval(expr, %Binding{matches: matches, nodes: nodes} = binding) do
    for values <- do_eval(expr, matches, nodes), values != [] do
      new_matches = values |> List.wrap() |> Enum.reduce(matches, &update_matches/2)
      %Binding{binding | matches: new_matches}
    end
  end

  defp do_eval(%Expr{type: :=, left: %Var{name: name, attr: attr}} = expr, matches, nodes) do
    %Expr{right: right} = expr

    for right_value <- do_eval(right, matches, nodes),
        do: {{name, attr}, to_value(right_value)}
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
    for value <- matches[name][attr] || nodes[name][attr], do: {{name, attr}, value}
  end

  defp do_eval(%Value{val: value}, _, _nodes), do: [from_value(value)]

  defp unwrap_value({{_, _}, value}), do: from_value(value)
  defp unwrap_value(value), do: value

  for comparison <- @comparisons do
    defp apply_expr(unquote(comparison), left, right), do: unquote(comparison)(left, right)
  end

  def update_matches({{name, attr}, value}, matches), do: deep_put(matches, [name, attr], value)
  def update_matches(_, matches), do: matches

  @doc """
  Execute binding
  """
  def exec(%Binding{rule: %Rule{then: then}} = binding) do
    new_binding =
      Enum.reduce(then, binding, fn expr, binding ->
        [binding] = eval(expr, binding)
        binding
      end)

    {new_binding, Changeset.from_binding_diff(binding, new_binding)}
  end
end
