defmodule Calypte.Error do
  @moduledoc """
  Dgraph or connection error are wrapped in Dlex.Error.
  """
  defexception [:reason]

  @type t :: %Calypte.Error{}

  @impl true
  def message(%{reason: reason}) do
    "error: #{inspect(reason)}"
  end
end
