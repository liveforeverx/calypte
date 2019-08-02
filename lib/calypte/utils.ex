defmodule Calypte.Utils do
  @moduledoc false

  alias Calypte.Value

  def deep_put(map, [key], value), do: put_in(map, [key], value)

  def deep_put(map, [key | keys], value),
    do: update_in(map, [key], &deep_put(&1 || %{}, keys, value))

  def timestamp(), do: :os.system_time()

  def from_value([value]), do: from_value(value)
  def from_value(values) when is_list(values), do: Enum.map(values, &from_value/1)
  def from_value(%Value{value: value}), do: value
  def from_value(value), do: value

  def to_value(values) when is_list(values), do: Enum.map(values, &to_value/1)
  def to_value(%Value{} = value), do: value
  def to_value(value), do: Value.new(value)
end
