defmodule TestHelper do
  def init_ctx(data, rules) do
    ctx = Calypte.init(data)
    rules = for rule <- List.wrap(rules), do: Calypte.string!(rule)
    Calypte.add_rules(ctx, rules)
  end
end

ExUnit.start()
