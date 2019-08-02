defmodule Calypte.ChangesetTest do
  use ExUnit.Case

  alias Calypte.{Changeset, Changeset.Change, Graph, Value}

  test "full example" do
    person = %{
      "type" => [Value.new("Person")],
      "name" => [Value.new("John")],
      "surname" => [Value.new("Smith")]
    }

    changes = [%Change{id: "1", values: person}]

    assert %Graph{nodes: %{"1" => ^person}, typed: %{"Person" => %{"1" => true}}} =
             apply_changes(Graph.new(), changes)
  end

  defp apply_changes(graph, changes), do: Graph.add_change(graph, %Changeset{changes: changes})
end
