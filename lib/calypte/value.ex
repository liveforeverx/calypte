defmodule Calypte.Value do
  @moduledoc """
  Timestamped value.
  """
  alias Calypte.Utils

  defstruct value: nil, id: nil

  def new(value), do: %__MODULE__{value: value, id: Utils.timestamp()}
end
