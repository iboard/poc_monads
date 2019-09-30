defmodule Monads.Maybe do
  alias Monads

  def maybe({nil, :maybe}), do: :nothing
  def maybe({x, :maybe}), do: x
  def maybe(nil), do: {nil, :maybe}
  def maybe(:nothing), do: {nil, :maybe}
  def maybe(value), do: {value, :maybe}
end
