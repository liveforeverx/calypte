data = %{
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

rule = """
@id "test_rule"

@if
  $child isa Person
    age < 18

@then
  $child's type = "child"
"""


Benchee.run(
  %{
    "Calypte.eval/1" => fn {ctx} ->
      %{executed?: true, exec_log: [_]} = ctx = Calypte.eval(ctx)
    end
  },
  before_scenario: fn _ ->
    ctx = Calypte.init(data)
    {:ok, rule} = Calypte.string(rule)
    ctx = Calypte.add_rules(ctx, [rule])
    {ctx}
  end
)
