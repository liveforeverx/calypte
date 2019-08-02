defmodule Calypte.Compiler do
  @moduledoc """
  Compiler for rules. Implements any sanity checks and optimization (till compilation to Elixir
  code in a future).
  """

  alias Calypte.Ast.{Var}
  alias Calypte.{Rule, Traverse}

  defstruct vars: %{}, current: nil

  @known_meta ["id", "if", "then"]

  @doc """
  Compile parsed ast. At the moment, it only propagates context information.
  """
  def compile(ast, _opts \\ []) do
    {rule, _compiler} = preprocess_ast(ast)
    {:ok, rule}
  end

  defp preprocess_ast(ast) do
    Enum.reduce(ast, {%Rule{}, %__MODULE__{}}, fn {key, ast}, {%{meta: meta} = rule, compiler} ->
      {ast, compiler} = Traverse.prewalk(ast, compiler, &preprocess_ast/2)

      cond do
        key in @known_meta -> {Map.put(rule, String.to_existing_atom(key), ast), compiler}
        true -> {%{rule | meta: Map.put(meta, key, ast)}, compiler}
      end
    end)
  end

  defp preprocess_ast(%Var{name: name, type: type} = var, %__MODULE__{} = compiler)
       when is_binary(type) do
    {var, %{compiler | current: name}}
  end

  defp preprocess_ast(%Var{name: nil} = var, %__MODULE__{current: current} = compiler) do
    {%Var{var | name: current}, compiler}
  end

  defp preprocess_ast(var, compiler) do
    {var, compiler}
  end
end
