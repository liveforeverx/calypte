defmodule Calypte.ParserTest do
  use ExUnit.Case

  alias Calypte.Ast.{Expr, Relation, Value, Var}

  describe "literals" do
    test "boolean" do
      assert {:ok, [%Value{line: 1, type: :boolean, val: true}]} == Calypte.parse("true")
      assert {:ok, [%Value{line: 1, type: :boolean, val: false}]} == Calypte.parse("false")
    end

    test "string" do
      assert {:ok, [%Value{line: 1, type: :string, val: "string"}]} == Calypte.parse(~s|"string"|)
    end

    test "numbers" do
      assert {:ok, [%Value{line: 1, type: :integer, val: 1}]} == Calypte.parse(~s|1|)
      assert {:ok, [%Value{line: 1, type: :float, val: 1.0}]} == Calypte.parse(~s|1.0|)
      assert {:ok, [%Value{line: 1, type: :integer, val: -1}]} == Calypte.parse(~s|-1|)
      assert {:ok, [%Value{line: 1, type: :integer, val: -10}]} == Calypte.parse(~s|-10|)
    end

    test "datetime" do
      # TODO: Datetime parsing
      assert {:ok, [%Value{type: :datetime}]} = Calypte.parse(~s|2018-01-01|)
      assert {:ok, [%Value{type: :datetime}]} = Calypte.parse(~s|2018-01-01T00:00:00|)
    end

    test "lists" do
      assert {:ok,
              [
                [
                  %Value{type: :datetime},
                  %Value{type: :string, val: "foo"},
                  %Value{type: :integer, val: -10}
                ]
              ]} = Calypte.parse(~s|[2018-01-01, "foo", -10]|)
    end
  end

  describe "variables" do
    test "type variables" do
      assert {:ok, [%Var{name: "father", type: "Person"}]} = Calypte.parse(~s|$father isa Person|)
    end

    @rule_full """
    $father isa Person
    $father's age > 18
    """

    @rule_short """
    $father isa Person
      age > 18
    """

    test "full and short form" do
      assert {:ok,
              [
                %Var{name: "father", type: "Person"},
                %Expr{type: :>, left: %Var{attr: "age", name: "father"}, right: %Value{val: 18}}
              ]} = Calypte.parse(@rule_full)

      assert {:ok,
              [
                %Var{name: "father", type: "Person"},
                %Expr{type: :>, left: %Var{attr: "age", name: nil}, right: %Value{val: 18}}
              ]} = Calypte.parse(@rule_short)
    end

    @rule_test """
    $father isa Person
      discount default 0
    """

    test "default values" do
      assert {:ok,
              [
                %Var{name: "father", type: "Person"},
                %Expr{
                  left: %Var{attr: "discount"},
                  right: %Value{type: :integer, val: 0},
                  type: :default
                }
              ]} = Calypte.parse(@rule_test)
    end
  end

  describe "graph matches" do
    test "type definition" do
      assert {:ok, [%Var{line: 1, name: "father", type: "Person"}]} =
               Calypte.parse(~s|$father isa Person|)
    end

    test "relationship" do
      assert {:ok,
              [
                %Relation{
                  from: %Var{line: 1, name: "father"},
                  edge: "has-child",
                  to: %Var{line: 1, name: "child", type: "Person"},
                  line: 1
                }
              ]} = Calypte.parse(~s|$father has-child $child isa Person|)
    end
  end

  describe "full examples" do
    @rule_test """
    @if
      $father isa Person
        discount

      $father has-child $child isa Person
        age > 18

    @then
      $father's discount = discount + 1

    """

    test "complex test" do
      {:ok, [{"if", if_expressions}, {"then", then_expressions}]} = Calypte.parse(@rule_test)

      assert [
               %Var{name: "father", type: "Person"},
               %Var{attr: "discount", name: nil, type: nil},
               %Relation{
                 edge: "has-child",
                 from: %Var{name: "father"},
                 to: %Var{name: "child", type: "Person"}
               },
               %Expr{
                 left: %Var{attr: "age"},
                 right: %Value{type: :integer, val: 18},
                 type: :>
               }
             ] = if_expressions

      assert [
               %Expr{
                 left: %Var{attr: "discount", name: "father"},
                 right: %Expr{
                   type: :+,
                   left: %Var{attr: "discount", name: nil},
                   right: %Value{type: :integer, val: 1}
                 },
                 type: :=
               }
             ] = then_expressions
    end
  end
end
