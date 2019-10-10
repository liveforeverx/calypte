defmodule Calypte.Compiler do
  @moduledoc """
  Compiler for rules. Implements any sanity checks and optimization (till compilation to Elixir
  code in a future).
  """

  alias Calypte.Ast.{Expr, Var, Value}
  alias Calypte.{Rule, Traverse, Utils}

  import Utils

  defstruct types: %{}, vars: %{}, key: nil, current_var: nil, modified_vars: %{}

  @known_meta ["id", "if", "then"]

  @doc """
  Compile parsed ast. At the moment, it only propagates context information.
  """
  def compile(ast, _opts \\ []) do
    rule = preprocess_ast(ast)
    {:ok, rule}
  end

  defp preprocess_ast(ast) do
    {%Rule{id: id} = rule, compiler} =
      Enum.reduce(ast, {%Rule{}, %__MODULE__{}}, fn {key, ast}, {rule, compiler} ->
        %{meta: meta} = rule
        compiler = %__MODULE__{compiler | key: key}
        {ast, compiler} = Traverse.prewalk(ast, compiler, &preprocess_ast/2)

        cond do
          key in @known_meta -> {Map.put(rule, String.to_existing_atom(key), ast), compiler}
          true -> {%{rule | meta: Map.put(meta, key, ast)}, compiler}
        end
      end)

    %__MODULE__{modified_vars: modified_vars, vars: vars} = compiler

    %Rule{rule | modified_vars: modified_vars, id: clean_id(id), vars: vars}
  end

  # save current scope
  defp preprocess_ast(%Var{name: name, type: type} = var, compiler)
       when is_binary(type) do
    {var, update_vars(%{compiler | current_var: name}, var)}
  end

  # apply current scope to unnamed attribute
  defp preprocess_ast(%Var{name: nil} = var, %__MODULE__{current_var: current_var} = compiler) do
    var = %Var{var | name: current_var}
    {var, update_vars(compiler, var)}
  end

  defp preprocess_ast(%Var{} = var, %__MODULE__{} = compiler),
    do: {var, update_vars(compiler, var)}

  defp preprocess_ast(%Expr{left: var, type: :=} = ast, %__MODULE__{key: "then"} = compiler) do
    %Var{name: name, attr: attr} = var
    %{modified_vars: modified_vars} = compiler
    {ast, %{compiler | modified_vars: deep_put(modified_vars, [name, attr], true)}}
  end

  defp preprocess_ast(var, compiler) do
    {var, compiler}
  end

  defp update_vars(%__MODULE__{types: types} = compiler, %Var{name: name, type: type})
       when is_binary(type) do
    %{compiler | types: deep_put(types, [name], type)}
  end

  defp update_vars(compiler, %Var{name: name, attr: nil} = var), do: compiler

  defp update_vars(compiler, %Var{name: name, attr: attr, type: type} = var) do
    %__MODULE__{key: key, types: types, vars: vars} = compiler
    %{compiler | vars: deep_put(vars, [key, types[name], attr], true)}
  end

  defp clean_id([%Value{val: id}]), do: id
  defp clean_id(_), do: nil
end
