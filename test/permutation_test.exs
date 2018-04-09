defmodule AljawadScheduler.PermutationTest do
  use ExUnit.Case
  alias AljawadScheduler.Permutation

  describe "remove element" do
    test "remove first element from array with one element" do
      assert {[], 1} = Permutation.remove_element([1], 0)
    end

    test "remove first element from array" do
      assert {[2, 3], 1} = Permutation.remove_element([1, 2, 3], 0)
    end

    test "remove element in the middle" do
      assert {[1, 3], 2} = Permutation.remove_element([1, 2, 3], 1)
    end

    test "remove last element" do
      assert {[1, 2], 3} = Permutation.remove_element([1, 2, 3], 2)
    end
  end

  describe "factorial" do
    test "factorial 0" do
      assert 1 = Permutation.factorial(0)
    end

    test "factorial 1" do
      assert 1 = Permutation.factorial(1)
    end

    test "factorial 2" do
      assert 2 = Permutation.factorial(2)
    end

    test "factorial 3" do
      assert 6 = Permutation.factorial(3)
    end

    test "factorial 4" do
      assert 24 = Permutation.factorial(4)
    end

    test "factorial 5" do
      assert 120 = Permutation.factorial(5)
    end
  end

  describe "multiplier" do
    test "multiplier 0" do
      assert 1 = Permutation.multiplier([])
    end

    test "multiplier 1" do
      assert 1 = Permutation.multiplier([1])
    end

    test "multiplier 2" do
      assert 1 = Permutation.multiplier(1..2)
    end

    test "multiplier 3" do
      assert 2 = Permutation.multiplier(1..3)
    end

    test "multiplier 4" do
      assert 6 = Permutation.multiplier(1..4)
    end

    test "multiplier 5" do
      assert 24 = Permutation.multiplier(1..5)
    end
  end

  describe "digit" do
    test "digit" do
      assert 0 = Permutation.digit(1, 3)
      assert 1 = Permutation.digit(4, 3)
    end
  end

  describe "create permutation" do
    setup do
      {:ok, array: ["a", "b", "c"]}
    end

    test "return empty array for empty args" do
      assert [] = Permutation.create_permutation([])
      assert [] = Permutation.create_permutation([], 0)
    end

    test "first permute for an array", %{array: array} do
      assert ["a", "b", "c"] = Permutation.create_permutation(array, 0)
    end

    test "second permute for an array", %{array: array} do
      assert ["a", "c", "b"] = Permutation.create_permutation(array, 1)
    end

    test "third permute for an array", %{array: array} do
      assert ["b", "a", "c"] = Permutation.create_permutation(array, 2)
    end

    test "4th permute for an array", %{array: array} do
      assert ["b", "c", "a"] = Permutation.create_permutation(array, 3)
    end

    test "5th permute for an array", %{array: array} do
      assert ["c", "a", "b"] = Permutation.create_permutation(array, 4)
    end

    test "6th permute for an array", %{array: array} do
      assert ["c", "b", "a"] = Permutation.create_permutation(array, 5)
    end

    # @tag timeout: 25_000_000
    # test "generate batches", %{array: array} do
    #   target = 1

    #   limit = Permutation.factorial(target)
    #   portion = 10_000

    #   group_size =
    #     (limit / portion)
    #     |> round

    #   for s <- 0..group_size do
    #     start_at = s * portion
    #     end_at = min((s + 1) * portion - 1, limit)

    #     Task.async(fn ->
    #       {t, nil} =
    #         :timer.tc(fn ->
    #           for i <- start_at..end_at do
    #             1..target
    #             |> Enum.to_list()
    #             |> Permutation.create_permutation(i)

    #             nil
    #           end

    #           nil
    #         end)

    #     end)
    #   end
    #   |> Enum.map(&Task.await(&1, :infinity))
    # end
  end
end
