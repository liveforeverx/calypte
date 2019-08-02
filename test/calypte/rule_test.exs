defmodule Calypte.RuleTest do
  use ExUnit.Case

  alias Calypte.{Binding, Rule, Value}

  describe "basic" do
    @rule """
    @if
      $person isa Person
        age >= 18
    """
    test "comparison" do
      {:ok, %Rule{if: [_, if_expr]}} = Calypte.string(@rule)
      age = Value.new(19)
      nodes = %{"person" => %{"age" => [age], "name" => [Value.new("John")]}}
      binding = %Binding{nodes: nodes}

      assert [%Binding{matches: %{"person" => %{"age" => ^age}}}] = Rule.eval(if_expr, binding)
    end
  end
end
