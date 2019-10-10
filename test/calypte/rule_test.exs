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

      assert [%Binding{matches: %{"person" => %{"age" => ^age}}}] = Rule.match(if_expr, binding)
    end

    @rule """
    @if
      $person isa Person
        age < 18
        discount

    @then
      $person.discount = $person.discount + 10
    """

    test "modified variables" do
      {:ok, rule} = Calypte.string(@rule)

      assert %Rule{if: [_ | if_exprs], modified_vars: %{"person" => %{"discount" => true}}} = rule

      age = Value.new(15)
      uid = Value.new("test_uid")

      nodes = %{"person" => %{"uid" => [uid], "age" => [age], "discount" => [Value.new(0)]}}
      assert [binding1] = Rule.match(if_exprs, %Binding{rule: rule, id_key: "uid", nodes: nodes})

      nodes = %{"person" => %{"uid" => [uid], "age" => [age], "discount" => [Value.new(10)]}}
      assert [binding2] = Rule.match(if_exprs, %Binding{rule: rule, id_key: "uid", nodes: nodes})

      # modified variables doesn't modify hash of binding if changed.
      assert Binding.calc_hash(binding1).hash == Binding.calc_hash(binding2).hash
    end
  end
end
