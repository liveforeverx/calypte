defmodule CalypteTest do
  use ExUnit.Case

  doctest Calypte

  @data %{
    "uid" => "1",
    "type" => "Person",
    "name" => "John",
    "surname" => "Smith",
    "age" => 42,
    "has_child" => [
      %{"uid" => "2", "type" => "Person", "name" => "Mike", "age" => 10},
      %{"uid" => "3", "type" => "Person", "name" => "Cindy", "age" => 16}
    ]
  }

  @relation_rule """
  @id "test_rule"

  @if
    $parent isa Person
      discount default 0
    $parent has_child $child isa Person
      age < 18

  @then
    $parent.discount = $parent.discount + 10
  """

  test "relation example" do
    ctx = TestHelper.init_ctx(@data, @relation_rule)

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)
    assert %{executed?: false} = ctx = Calypte.eval(ctx)

    assert %{value: 20} = ctx["1"]["discount"]
  end

  @basic_rule """
  @id "basic_rule"

  @if
    $child isa Person
      age < 18

  @then
    $child.check_type = "child"
  """

  test "basic example" do
    ctx = TestHelper.init_ctx(@data, @basic_rule)

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)
    assert %{executed?: false} = Calypte.eval(ctx)
  end

  @basic_math """
  @id "basic_math"

  @if
    $child isa Person
      age < 12
      discount default 0

  @then
    $child.discount = $child.discount + 10
  """

  test "math test" do
    ctx = TestHelper.init_ctx(@data, @basic_math)

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: false} = Calypte.eval(ctx)
  end

  @chain_rule """
  @id "chain_rule"

  @if
    $child isa Person
      discount > 0

  @then
    $child.discount = $child.discount + 2
  """

  test "truth maintainance with chained rules" do
    ctx = TestHelper.init_ctx(@data, [@chain_rule, @basic_math])

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)
    ctx = Calypte.add_change(ctx, %{"uid" => "2", "age" => 12})
    assert nil == ctx["2"]["discount"]
  end

  test "manual rule deletion" do
    ctx = TestHelper.init_ctx(@data, [@basic_math, @chain_rule])

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)

    ctx = Calypte.delete_rules(ctx, ["basic_math"], true)
    assert nil == ctx["2"]["discount"]
  end
end
