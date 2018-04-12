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

  describe "expand range" do
    test "valid?" do
      assert true == Permutation.valid?(0..0)
      assert true == Permutation.valid?(12..13)
      assert true == Permutation.valid?(0..479_001_599)
      assert true == Permutation.valid?(0..23)
      assert true == Permutation.valid?(12..17)
      assert false == Permutation.valid?(0..22)
      assert false == Permutation.valid?(0..20)
      assert false == Permutation.valid?(:any_value)
    end

    test "to_range" do
      assert {:ok, 0..23} == Permutation.to_range(24)
      assert {:ok, 0..479_001_599} == Permutation.to_range(479_001_600)
      assert {:error, :not_valid} == Permutation.to_range(22)
    end

    test "expand" do
      assert {:ok, [0..5, 6..11, 12..17, 18..23]} == Permutation.expand(0..23)

      assert {:ok,
              [
                0..1,
                2..3,
                4..5,
                6..7,
                8..9,
                10..11,
                12..13,
                14..15,
                16..17,
                18..19,
                20..21,
                22..23
              ]} == Permutation.expand(0..23, 2)

      assert {:ok, [12..13, 14..15, 16..17]} == Permutation.expand(12..17)

      assert {:ok,
              [
                12..12,
                13..13,
                14..14,
                15..15,
                16..16,
                17..17
              ]} == Permutation.expand(12..17, 10)

      to = 2_432_902_008_176_639_999
      assert {:ok, _} = Permutation.expand(0..to)
      to = 620_448_401_733_239_439_359_999
      assert {:ok, _} = Permutation.expand(0..to)
      to = 8_683_317_618_811_886_495_518_194_401_279_999_999
      assert {:ok, _} = Permutation.expand(0..to)
      to = 8_683_317_618_811_886_495_518_194_401_279_999_998
      assert {:error, :not_valid} = Permutation.expand(0..to)
      assert {:error, :not_valid} == Permutation.expand(0..20)
    end

    test "base" do
      assert {:ok, 4} == Permutation.base(0..23, 4)
      assert {:ok, 4} == Permutation.base(0..23, 5)
      assert {:ok, 10} == Permutation.base(3_628_800..7_257_599, 12)
      assert {:error, :not_valid} == Permutation.base(0..23, 3)
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
