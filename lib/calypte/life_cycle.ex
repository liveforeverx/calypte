defmodule Calypte.LifeCycle do
  @moduledoc """
  Execution hooks, which enables plugin architecture to enable
  """

  # @callback after_exec_change(state, changeset, binding) :: { state
  #            {:ok, state}
  #            | {:ok, state, timeout | :hibernate | {:continue, term}}
  #            | :ignore
  #            | {:stop, reason :: any}
  #          when state: any

  # defmacro __using__(opts) do
  #  quote location: :keep, bind_quoted: [opts: opts] do
  #    @behaviour Calypte.LifeCycle

  #    def after_change() do
  #    end

  #    defoverridable code_change: 3, terminate: 2, handle_info: 2, handle_cast: 2, handle_call: 3
  #  end
  # end

  defstruct after_execution: [], after_change: []

  def after_change(%__MODULE__{after_change: after_change}, context, change) do
    for module <- after_change, do: module.after_change(context, change)
  end
end
