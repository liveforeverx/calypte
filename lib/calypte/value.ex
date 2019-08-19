defmodule Calypte.Value do
  @moduledoc """
  Timestamped value.
  """
  alias Calypte.Utils

  defstruct value: nil, id: nil, virtual: false

  def new(value, virtual \\ false) do
    timestamp = if virtual, do: 0, else: Utils.timestamp()
    %__MODULE__{value: value, id: timestamp, virtual: virtual}
  end
end
