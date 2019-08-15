defmodule CalypteTest do
  use ExUnit.Case

  alias Calypte.Graph

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

  # @rule """
  # @id "test_rule"

  # @if
  #   $parent isa Person
  #   $child has-child $child isa Person
  #     age < 18

  # @then
  #   $parent has-discount $discount isa Discount
  #   $discount's type = "family"
  # """

  @basic_rule """
  @id "basic_rule"

  @if
    $child isa Person
      age < 18

  @then
    $child's type = "child"
  """

  test "full test" do
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
    $child's discount = $child's discount + 10
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
    $child's discount = $child's discount + 2
  """

  test "truth maintainance with chained rules" do
    ctx = TestHelper.init_ctx(@data, [@basic_math, @chain_rule])

    assert %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    assert %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)
    %{graph: graph} = Calypte.add_change(ctx, %{"uid" => "2", "age" => 12})
    assert Graph.get_node(graph, "2")["discount"] == nil
  end
end
