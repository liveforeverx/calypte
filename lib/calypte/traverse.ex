defmodule Calypte.Traverse do
  @moduledoc """
  Traverse of a structure
  """

  alias Calypte.Traversable

  @type traversable :: any

  @doc """
  Performs a depth-first, pre-order traversal using an accumulator.
  """
  @spec prewalk(traversable, any, (traversable, any -> {traversable, any})) :: {traversable, any}
  def prewalk(traversable, acc, fun) when is_function(fun, 2) do
    traverse(traversable, acc, fun, &{&1, &2})
  end

  @doc """
  Performs a depth-first, post-order traversal using an accumulator.
  """
  @spec postwalk(traversable, any, (traversable, any -> {traversable, any})) :: {traversable, any}
  def postwalk(traversable, acc, fun) when is_function(fun, 2) do
    traverse(traversable, acc, &{&1, &2}, fun)
  end

  def traverse(traversable, acc, pre, post) when is_function(pre, 2) and is_function(post, 2) do
    Traversable.traverse(traversable, acc, pre, post)
  end

  def list_traverse(traversable, acc, pre, post) do
    Enum.map_reduce(traversable, acc, fn part, acc ->
      {part, acc} = pre.(part, acc)
      Traversable.traverse(part, acc, pre, post)
    end)
  end
end

defprotocol Calypte.Traversable do
  def traverse(traversable, acc, pre, post)
end

defimpl Calypte.Traversable, for: List do
  alias Calypte.Traverse

  def traverse(traversable, acc, pre, post) when is_list(traversable) do
    {traversable, acc} = Traverse.list_traverse(traversable, acc, pre, post)
    post.(traversable, acc)
  end
end
