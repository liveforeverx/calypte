defmodule Calypte.LifeCycle do
  @moduledoc """
  Execution hooks, which enables plugin architecture to enable
  """

  defstruct after_execution: [], after_change: []

  def after_change(%__MODULE__{after_change: after_change}, context, change) do
    for module <- after_change, do: module.after_change(context, change)
  end
end
