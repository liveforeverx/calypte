defmodule Calypte.Value do
  @moduledoc """
  Timestamped value.
  """
  alias Calypte.Utils

  defstruct value: nil, id: nil, virtual: false

  def new(value, virtual \\ false),
    do: %__MODULE__{value: value, id: Utils.timestamp(), virtual: virtual}
end
