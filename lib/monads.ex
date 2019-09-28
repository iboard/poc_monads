defmodule Monads do
  @moduledoc """
  A monad or factor transforming input to annotated input

  Assuming we have a function `incrementor(n)` returning the
  same type as n but incremented.

  With pure Elixir and Enum we can do something like

      result =
        [1, 2, 3]
        |> Enum.reduce([], fn i, acc ->
          [incrementor(i) | acc]
        end)
        |> Enum.reverse()

      assert [2, 3, 4] == result

  But that's hard to read and leeds to a mess when we pipe such
  reductions.

  With Monads we can use

      result =
        [1, 2, 3]
        |> Monads.annotate(&incrementor/1)
        |> Monads.reduce()

      assert [4, 3, 2] == result

  which reads much nicer
  """

  @doc """
  Annotate something

  ## Examples

      iex> Monads.annotate(123, :annotation)
      {123, :annotation}

      iex> f = fn(n) -> n * n end
      iex> assert {2, f} == Monads.annotate(2, f)
      true

  """
  def annotate(list_of_values, annotation) when is_list(list_of_values) do
    Enum.map(list_of_values, fn v -> annotate(v, annotation) end)
  end

  def annotate(value, annotation) do
    {value, annotation}
  end

  @doc """
  Reduce a list of values with a given annotation
  Valid ooptions `keep_order: true`
  """
  def reduce(annotated_values, opts \\ [])

  def reduce(annotated_values, keep_order: true) do
    reduce(annotated_values) |> Enum.reverse()
  end

  def reduce(annotated_values, []) do
    Enum.reduce(annotated_values, [], fn {v, annotator}, acc ->
      [resolve(v, annotator) | acc]
    end)
  end

  # [
  #   {{{1, F1}, F1}, F2},
  #   {{{2, F1}, F2}, F2}
  # ]
  defp resolve(left, fun)

  defp resolve({inner, inner_fun}, fun) do
    resolve(inner, inner_fun)
    |> fun.()
  end

  defp resolve(inner, fun) do
    fun.(inner)
  end
end
