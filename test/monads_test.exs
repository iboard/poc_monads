defmodule MonadsTest do
  use ExUnit.Case
  doctest Monads

  import Monads, only: [annotate: 2, reduce: 1, reduce: 2]

  def incrementor(n), do: n + 1
  def squarer(n), do: n * n

  #
  # Two functions simmulating business logic
  #

  # Adults are born before 2000
  def adult_state(%{yob: yob} = input) do
    input
    |> Map.merge(%{adult_state: yob < 2000})
  end

  # The key is "nameYEAR" where name is lowercase for teens
  # and uppercase for adults.
  defp build_key(input) do
    if input.adult_state do
      input |> Map.merge(%{key: "#{input.name |> String.upcase()}#{input.yob}"})
    else
      input |> Map.merge(%{key: "#{input.name |> String.downcase()}#{input.yob}"})
    end
  end

  # Simmulate a simple repositor (our database)
  defp repo(%{id: id, method: :get}) do
    case id do
      1 -> %{name: "Bob", yob: 1950}
      2 -> %{name: "Alice", yob: 2001}
    end
  end

  #
  # Monads Specifications
  #

  describe "Basic functions" do
    #
    # Annotating a value is nothing more than wrapping the value
    # in a tuple with an annotation. value and annotation can be
    # just everything.
    #
    test "annotate different types" do
      assert annotate(1, :annotation) == {1, :annotation}
      assert annotate(:x, :annotation) == {:x, :annotation}
      assert annotate(%{key: "value"}, :annotation) == {%{key: "value"}, :annotation}
    end

    #
    # The fun comes when the annotation is a function ;-)
    #
    test "annotate with a function" do
      f1 = fn a -> a * 2 end
      f2 = fn a -> a + f1.(a) end
      assert {1, f1} = annotate(1, f1)
      assert {1, f2} = annotate(1, f2)
    end

    #
    # For now we have at least a nicer code as we would have with Enum.reduce
    #
    test "reduce a list of values with annotations when order doesn't matter" do
      result =
        [1, 2, 3]
        |> annotate(&incrementor/1)
        |> reduce()

      assert [4, 3, 2] == result
    end
  end

  describe "Compare Monads vs Elixir.Enum functions" do
    test "without using Monads module" do
      # Code that doesn't use the Monads module
      # Is harder to read and doesn't look so nice
      result =
        [1, 2, 3]
        |> Enum.reduce([], fn i, acc ->
          [incrementor(i) | acc]
        end)
        |> Enum.reverse()

      assert [2, 3, 4] == result
    end

    test "With Monads" do
      # The code is more compact and easier to read,
      # compared with the test above.
      result =
        [1, 2, 3]
        |> annotate(&incrementor/1)
        |> reduce(keep_order: true)

      assert [2, 3, 4] == result
    end
  end

  describe "Piping Monads" do
    test "Pipe two factories" do
      result =
        [1, 2, 3]
        |> annotate(&incrementor/1)
        |> annotate(&squarer/1)
        |> reduce(keep_order: true)

      assert [4, 9, 16] == result
    end

    test "Pipe one factor multiple times" do
      result =
        [1, 2, 3]
        |> annotate(&squarer/1)
        |> annotate(&squarer/1)
        |> annotate(&squarer/1)
        |> reduce(keep_order: true)

      assert [1, 256, 6561] == result
    end
  end

  describe "Composing a map with monads" do
    test "Composing a map" do
      result =
        [%{name: "Bob", yob: 1950}, %{name: "Alice", yob: 2010}]
        |> annotate(&adult_state/1)
        |> annotate(&build_key/1)
        |> reduce()

      assert [
               %{adult_state: false, key: "alice2010", name: "Alice", yob: 2010},
               %{adult_state: true, key: "BOB1950", name: "Bob", yob: 1950}
             ] == result
    end
  end

  describe "Integration" do
    test "Request -> Interactor -> Resonse" do
      # request_model
      # |> request from a repo
      # |> inject adult state (do something with loaded thing and modify the request)
      # |> build_key depends on adult state (do more modifications based on that before)
      # |> reduce to get the result which will be returned as a response.
      result =
        [
          %{id: 1, method: :get},
          %{id: 2, method: :get}
        ]
        |> annotate(&repo/1)
        |> annotate(&adult_state/1)
        |> annotate(&build_key/1)
        |> reduce()

      assert [
               %{adult_state: false, key: "alice2001", name: "Alice", yob: 2001},
               %{adult_state: true, key: "BOB1950", name: "Bob", yob: 1950}
             ] == result
    end
  end

  describe "Integration with Flow" do
    defp simmulate_slow(n) do
      :timer.sleep(10)
      n
    end

    defp simmulate_fast(n) do
      :timer.sleep(1)
      n
    end

    test "Work in parallel" do
      max_n = 10
      slow_path = 10
      slow_calculations = 2
      fast_path = 1
      fast_calculations = 10
      max_execution = max_n * (slow_path * slow_calculations + fast_path * fast_calculations)

      ts_start = System.monotonic_time(:millisecond)

      0..max_n
      |> Stream.map(& &1)
      |> Flow.from_enumerable()
      # Two slow
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_slow/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_slow/1) end)
      # And 10 fast calls
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.flat_map(fn n -> annotate([n], &simmulate_fast/1) end)
      |> Flow.partition()
      |> Flow.flat_map(fn n -> reduce([n]) end)
      |> Flow.reduce(fn -> [] end, fn n, acc ->
        [n | acc]
      end)
      |> Enum.to_list()

      ts_end = System.monotonic_time(:millisecond)

      exec_time = ts_end - ts_start
      factor = max_execution / exec_time

      IO.puts("""

        Performance with Flow:

        Sequential fastest possible time: #{max_execution / 1000} secs.
        With parallel Flow              : #{exec_time / 1000} secs.
        Factor                          : #{factor} times faster.
      """)

      assert ts_end - ts_start < max_execution
    end

    test "Work in sequence" do
      max_n = 10
      slow_path = 10
      slow_calculations = 2
      fast_path = 1
      fast_calculations = 10
      max_execution = max_n * (slow_path * slow_calculations + fast_path * fast_calculations)

      ts_start = System.monotonic_time(:millisecond)

      0..max_n
      |> Enum.map(& &1)
      # Two slow
      |> annotate(&simmulate_slow/1)
      |> annotate(&simmulate_slow/1)
      # And 10 fast calls
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> annotate(&simmulate_fast/1)
      |> reduce()
      |> Enum.to_list()

      ts_end = System.monotonic_time(:millisecond)

      exec_time = ts_end - ts_start
      factor = max_execution / exec_time

      IO.puts("""

        Performance without Flow:

        Sequential fastest possible time: #{max_execution / 1000} secs.
        Without parallel Flow           : #{exec_time / 1000} secs.
        Factor                          : #{factor} times slower.
      """)

      assert ts_end - ts_start > max_execution
    end
  end
end
