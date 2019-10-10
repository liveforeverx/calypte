defmodule TestHelper do
  def init_ctx(data, rules, opts \\ []) do
    ctx = Calypte.init(data, opts)
    rules = for rule <- List.wrap(rules), do: Calypte.string!(rule)
    Calypte.add_rules(ctx, rules)
  end
end

ExUnit.start()
