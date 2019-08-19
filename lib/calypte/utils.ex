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

  def to_value(values, virtual \\ false)
  def to_value(values, virtual) when is_list(values), do: Enum.map(values, &to_value(&1, virtual))
  def to_value(%Value{} = value, _), do: value
  def to_value(value, virtual), do: Value.new(value, virtual)

  def wrap(list), do: List.wrap(list)

  def unwrap([]), do: nil
  def unwrap([value]), do: value
  def unwrap(value) when not is_list(value), do: value

  def to_map(%Value{} = value), do: from_value(value)

  def to_map(map) when is_map(map) do
    for {key, value} <- map, into: %{}, do: {key, to_map(value)}
  end

  def to_map(list) when is_list(list), do: Enum.map(list, &to_map/1)
  def to_map(value), do: value
end
