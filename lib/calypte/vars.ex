defmodule Calypte.Vars do
  @moduledoc """
  Creating, modifying and checking of typed variable maps for optimizing searches
  """

  alias Calypte.Changeset
  alias Changeset.Change

  @doc """
  Create variables map from changeset
  """
  def from_changeset(%Changeset{changes: changes}, vars \\ %{}) do
    Enum.reduce(changes, vars, fn %Change{id: id, meta: types, delete: delete, add: add}, vars ->
      values = Map.merge(delete, add)

      Enum.reduce(types, vars, fn type, vars ->
        type_vars = Enum.reduce(values, vars[type] || %{}, &Map.put(&2, elem(&1, 0), true))
        type_vars = Map.update(type_vars, :ids, MapSet.new([id]), &MapSet.put(&1, id))
        Map.put(vars, type, type_vars)
      end)
    end)
  end

  def in_pattern?(vars, pattern) do
    Enum.any?(pattern, fn {type, attrs} ->
      case Map.get(vars, type) do
        nil -> false
        type_vars -> Enum.any?(attrs, &Map.has_key?(type_vars, elem(&1, 0)))
      end
    end)
  end
end
