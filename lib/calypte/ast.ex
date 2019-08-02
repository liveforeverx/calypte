defmodule Calypte.Ast do
  @moduledoc """
  Abstract syntax tree definition for a rule language used in calypto.
  """

  defmodule Relation do
    defstruct from: nil, to: nil, edge: nil, line: 0
  end

  defmodule Expr do
    defstruct type: nil, left: nil, right: nil, line: 0
  end

  defmodule Var do
    defstruct name: nil, attr: nil, type: nil, line: 0
  end

  defmodule Function do
    defstruct name: nil, args: [], line: 0
  end

  defmodule Value do
    defstruct type: nil, val: nil, line: 0
  end
end

alias Calypte.{Traverse, Traversable}
alias Calypte.Ast.{Relation, Expr, Var, Function, Value}

defimpl Traversable, for: Relation do
  def traverse(%Relation{from: from, to: to} = relation, acc, pre, post) do
    {[from, to], acc} = Traverse.list_traverse([from, to], acc, pre, post)
    post.(%{relation | from: from, to: to}, acc)
  end
end

defimpl Traversable, for: Expr do
  def traverse(%Expr{left: left, right: right} = expr, acc, pre, post) do
    {[left, right], acc} = Traverse.list_traverse([left, right], acc, pre, post)
    post.(%{expr | left: left, right: right}, acc)
  end
end

defimpl Traversable, for: Var do
  def traverse(%Var{} = var, acc, _pre, post), do: post.(var, acc)
end

defimpl Traversable, for: Function do
  def traverse(%Function{args: args} = function, acc, pre, post) do
    {args, acc} = Traverse.list_traverse(args, acc, pre, post)
    post.(%{function | args: args}, acc)
  end
end

defimpl Traversable, for: Value do
  def traverse(%Value{} = value, acc, _pre, post), do: post.(value, acc)
end
