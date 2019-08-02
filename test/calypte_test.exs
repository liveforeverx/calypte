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
      %{"uid" => "2", "type" => "Person", "name" => "Mike", "age" => 15},
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

  @rule """
  @id "test_rule"

  @if
    $child isa Person
      age < 18

  @then
    $child's type = "child"
  """

  test "full test" do
    ctx = Calypte.init(@data)
    {:ok, rule} = Calypte.string(@rule)
    ctx = Calypte.add_rules(ctx, [rule])

    %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    %{executed?: true, exec_log: [_, _]} = ctx = Calypte.eval(ctx)
    %{executed?: false} = Calypte.eval(ctx)
  end
end
