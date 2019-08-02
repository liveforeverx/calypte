defmodule Calypte.CompilerTest do
  use ExUnit.Case

  alias Calypte.Ast.{Expr, Relation, Value, Var}
  alias Calypte.Rule

  @rule """
  @if
    $father isa Person
      discount

    $father has-child $child isa Person
      age > 18
  """

  test "variable propagation" do
    assert {:ok, %Rule{if: if_match}} = Calypte.string(@rule)

    assert [
             %Var{name: "father", type: "Person"},
             %Var{attr: "discount", name: "father", type: nil},
             %Relation{
               edge: "has-child",
               from: %Var{name: "father", type: nil},
               to: %Var{name: "child", type: "Person"}
             },
             %Expr{
               left: %Var{attr: "age", name: "child"},
               right: %Value{type: :integer, val: 18},
               type: :>
             }
           ] = if_match
  end
end
