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

  @doc """
  Do a Enum.reduce but ignore Maybe.nothing
  """
  def reduce(annotated_values, start_value, block) do
    Enum.reduce(annotated_values, start_value, fn m, acc ->
      case Monads.Maybe.maybe(m) do
        :nothing -> acc
        v -> block.(v, acc)
      end
    end)
  end

  @doc """
  Do a Enum.map but ignore Maybe.nothing
  """
  def map(annotated_values, block) do
    Enum.map(annotated_values, fn m ->
      case Monads.Maybe.maybe(m) do
        :nothing -> :nothing
        v -> block.(v)
      end
    end)
    |> Enum.filter(&(&1 != :nothing))
  end

  @doc """
  Do a Enum.each but ignore Maybe.nothing
  """
  def each(annotated_values, block) do
    map(annotated_values, & &1)
    |> Enum.each(fn m -> block.(m) end)
  end

  @doc """
  Pipe through functions returning either {:ok, val} or {:error, reason}
  and returns [ok: [results], errors: [errors]]
  """
  def accumulate([ok: oks, errors: errors, warnings: warnings], {:ok, result}) do
    [ok: oks ++ [result], errors: errors, warnings: warnings]
  end

  def accumulate([ok: oks, errors: errors, warnings: warnings], {:error, error}) do
    [ok: oks, errors: errors ++ [error], warnings: warnings]
  end

  def accumulate([ok: oks, errors: errors, warnings: warnings], result) do
    [
      ok: oks,
      errors: errors,
      warnings: warnings ++ ["Ignore #{inspect(result)}"]
    ]
  end

  def accumulate(result) do
    accumulate([ok: [], errors: [], warnings: []], result)
  end

  @doc """
    return the state of the pipe before the first
    error occurs.
  """
  def stop_at_error({:stopped, input}, _fun), do: {:stopped, input}

  def stop_at_error({:ok, input}, {:error, _}), do: {:stopped, input}
  def stop_at_error({:ok, input}, {:ok, value}), do: {:ok, value}

  def stop_at_error({:ok, input}, fun) when is_function(fun) do
    input |> fun.()
  end

  def stop_at_error(input, fun) when is_function(fun) do
    case fun.(input) do
      {:ok, new_value} -> {:ok, new_value}
      {:error, _error} -> {:stopped, input}
      unexpected -> {:stopped, "unexpected: #{inspect(unexpected)}"}
    end
  end

  def stop_at_error(input, {:ok, f}), do: stop_at_error({:ok, input}, {:ok, f})
  def stop_at_error(input, {:error, f}), do: stop_at_error({:ok, input}, {:error, f})

  def final({:stopped, last_result}), do: last_result
  def final({:ok, result}), do: result
  def final(unexpected), do: {:error, inspect(unexpected)}

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
