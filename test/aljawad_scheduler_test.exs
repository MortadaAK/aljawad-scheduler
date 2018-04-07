# defmodule AljawadSchedulerTest do
#   use ExUnit.Case
#   doctest AljawadScheduler

#   test "greets the world" do
#     assert AljawadScheduler.hello() == :world
#   end
# end

defmodule AljawadScheduler.SchedulerTest do
  use ExUnit.Case
  alias AljawadScheduler.Scheduler

  test "prepare machine schedule" do
    assert %{m1: {[s: 10], 10, 0, 0}} =
             %{m1: 10}
             |> Scheduler.prepare_machines()
  end

  test "add a job to a machine" do
    assert {%{m1: {[s: 10, j1: 5], 15, 0, 0}}, 15} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {0, 5})
  end

  test "minimum possible remaining hours" do
    schedule = %{
      m1: {[s: 10], 10, 0, 0},
      m2: {[s: 5], 5, 0, 0},
      m3: {[s: 0], 0, 0, 0},
      m4: {[s: 15], 15, 0, 0},
      m5: {[s: 2], 2, 0, 0}
    }

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 2],
      j2: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
    }

    assert %{m1: 14, m2: 9, m3: 2, m4: 21, m5: 17} = Scheduler.min_remaining(schedule, jobs)
  end

  test "maximum minimum possible remaining hours" do
    schedule = %{
      m1: {[s: 10], 10, 0, 0},
      m2: {[s: 5], 5, 0, 0},
      m3: {[s: 0], 0, 0, 0},
      m4: {[s: 15], 15, 0, 0},
      m5: {[s: 2], 2, 0, 0}
    }

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 2],
      j2: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
    }

    assert 21 = Scheduler.max_min_remaining(schedule, jobs)
  end

  test "max of sum of total hours per machine" do
    assert %{m1: 4, m2: 4, m3: 2, m4: 6, m5: 15} =
             Scheduler.max_total_hours(%{
               j1: [m1: 2, m2: 2, m4: 2],
               j4: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
             })
  end

  test "add a job to a machine with a lag" do
    assert {%{
              m1: {[s: 10, l: 5, j1: 5], 20, 5, 0}
            },
            20} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {15, 5})
  end

  test "add a job to a machine with a waiting" do
    assert {%{
              m1: {[s: 10, w: 5, j1: 5], 15, 0, 5}
            },
            15} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {5, 5})
  end

  describe "schedule" do
    setup do
      machines = %{m1: 10, m2: 5, m3: 0, m4: 15}

      jobs = %{
        j1: [m1: 2, m2: 2, m4: 6],
        j2: [m1: 3, m3: 6, m4: 2],
        j3: [m2: 2, m3: 4, m4: 1],
        j4: [m1: 2, m2: 2, m3: 1, m4: 1]
      }

      {:ok, jobs: jobs, machines: machines}
    end

    test "add a job to a schedule", %{jobs: %{j1: job}, machines: machines} do
      assert %{
               m1: {[s: 10, j1: 2], 12, 0, 0},
               m2: {[s: 5, l: 7, j1: 2], 14, 7, 0},
               m3: {[s: 0], 0, 0, 0},
               m4: {[s: 15, w: 1, j1: 6], 21, 0, 1}
             } =
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_job(:j1, job)
    end

    test "add multiple jobs to a schedule", %{jobs: jobs, machines: machines} do
      wanted = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert wanted ==
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_jobs(jobs)
    end

    test "add multiple jobs to a schedule bay passing the permute number", %{
      jobs: jobs,
      machines: machines
    } do
      wanted = %{
        m1: {[s: 10, j4: 2, j2: 3, j1: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j4: 2, j3: 2, l: 1, j1: 2], 19, 8, 0},
        m3: {[s: 0, l: 14, j4: 1, l: 1, j3: 4, w: 5, j2: 6], 26, 15, 5},
        m4: {[s: 15, j4: 1, l: 4, j3: 1, l: 5, j2: 2, w: 9, j1: 6], 34, 9, 9}
      }

      assert wanted ==
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_jobs(jobs, 23)
    end

    test "calculate sim of lag hours" do
      schedule = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert 25 = Scheduler.get_lags(schedule)
    end

    test "calculate sim of waiting hours" do
      schedule = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert 12 = Scheduler.get_waiting(schedule)
    end
  end
end

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
    #     |> IO.inspect()

    #   for s <- 0..group_size do
    #     start_at = s * portion
    #     end_at = min((s + 1) * portion - 1, limit)
    #     IO.inspect("#{start_at}..#{end_at} Started")

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

    #       IO.inspect("#{start_at}..#{end_at} Ended #{t / 1_000_000}")
    #     end)
    #   end
    #   |> Enum.map(&Task.await(&1, :infinity))
    # end
  end
end

defmodule AljawadScheduler.ScheduleRunnerTest do
  use ExUnit.Case

  alias AljawadScheduler.ScheduleRunner

  setup do
    machines = %{m1: 10, m2: 5, m3: 0, m4: 15}

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m1: 3, m3: 6, m4: 2],
      j3: [m2: 2, m3: 4, m4: 1],
      j4: [m1: 2, m2: 2, m3: 1, m4: 1]
    }

    {:ok, jobs: jobs, machines: machines, name: :scheduler1233}
  end

  test "initialize with machines", args do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok,
            %{
              m1: {[s: 10], 10, 0, 0},
              m2: {[s: 5], 5, 0, 0},
              m3: {[s: 0], 0, 0, 0},
              m4: {[s: 15], 15, 0, 0}
            }} = ScheduleRunner.machines(pid)
  end

  test "initialize with jobs", args = %{jobs: jobs} do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok, ^jobs} = ScheduleRunner.jobs(pid)
  end

  test "initialize with first schedule", args = %{jobs: _jobs} do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok, 25} = ScheduleRunner.max(pid)

    assert {:ok,
            %{
              m1: {[s: 10, j4: 2, j1: 2, j2: 3], 17, 0, 0},
              m2: {[s: 5, j3: 2, l: 5, j4: 2, j1: 2], 16, 5, 0},
              m3: {[s: 0, l: 7, j3: 4, l: 3, j4: 1, l: 2, j2: 6], 23, 12, 0},
              m4: {[s: 15, w: 4, j3: 1, w: 1, j4: 1, w: 1, j1: 6, j2: 2], 25, 0, 6}
            }} = ScheduleRunner.current_schedule(pid)
  end

  test "set schedule", args do
    new_schedule = %{
      m1: {[s: 10, j4: 2, j1: 2, j2: 3], 17, 0, 0},
      m2: {[s: 5, j3: 2, l: 5, j4: 2, j1: 2], 16, 5, 0},
      m3: {[s: 0, l: 7, j3: 4, l: 3, j4: 1, l: 2, j2: 6], 23, 12, 0},
      m4: {[s: 15, w: 4, j3: 1, w: 1, j4: 1, w: 1, j1: 6, j2: 2], 25, 0, 6}
    }

    assert {:ok, pid} = ScheduleRunner.start_link(args)
    assert :ok = ScheduleRunner.set_schedule(pid, new_schedule)
    assert {:ok, ^new_schedule} = ScheduleRunner.current_schedule(pid)
  end

  test "schedule all" do
    machines = %{m1: 10, m2: 5, m3: 0, m4: 15, m5: 5, m6: 2, m7: 20}

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m1: 3, m3: 6, m4: 2],
      j3: [m2: 2, m3: 4, m4: 1],
      j4: [m1: 2, m2: 2, m3: 1, m4: 1],
      j5: [m1: 4, m6: 12, m3: 16, m7: 6],
      j6: [m3: 6, m4: 12, m5: 16, m7: 6]
    }

    {:ok, pid} = ScheduleRunner.start_link(%{machines: machines, jobs: jobs, name: :schedule123})

    assert {:ok,
            %{
              m1: {[s: 10, j4: 2, j1: 2, j2: 3, j5: 4], 21, 0, 0},
              m2: {[s: 5, j3: 2, l: 5, j4: 2, j1: 2], 16, 5, 0},
              m3: {[s: 0, j6: 6, l: 1, j3: 4, l: 3, j4: 1, l: 2, j2: 6, l: 10, j5: 16], 49, 16, 0},
              m4:
                {[s: 15, w: 9, j6: 12, w: 16, j3: 1, w: 13, j4: 1, w: 13, j1: 6, w: 12, j2: 2],
                 37, 0, 63},
              m5: {[s: 5, l: 22, j6: 16], 43, 22, 0},
              m6: {[s: 2, l: 19, j5: 12], 33, 19, 0},
              m7: {[s: 20, l: 23, j6: 6, j5: 6], 55, 23, 0}
            }} = ScheduleRunner.start_scheduling(pid)
  end

  @tag timeout: :infinity
  test "schedule all (v17)" do
    machines = %{m1: 0, m2: 0, m3: 0, m4: 0, m5: 0, m6: 0, m7: 0}

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m1: 6, m3: 6, m4: 2],
      j3: [m2: 2, m3: 4, m4: 1],
      j4: [m1: 4, m2: 2, m3: 1, m4: 1],
      j5: [m1: 4, m6: 12, m3: 16, m7: 6],
      j6: [m3: 6, m4: 12, m5: 10, m7: 6],
      j7: [m2: 3, m4: 5, m7: 10, m6: 7],
      j8: [m1: 12, m4: 5, m7: 10, m6: 6],
      j9: [m1: 3, m2: 15, m5: 14, m7: 15],
      j10: [m1: 3, m4: 5, m6: 10, m7: 8],
      j11: [m1: 13, m2: 6, m4: 5, m3: 5, m6: 10, m7: 6],
      j12: [m2: 3, m2: 3, m4: 5, m3: 15, m7: 6],
      j13: [m2: 12, m3: 5, m4: 10, m7: 8],
      j14: [m1: 6, m2: 6, m3: 12, m4: 12, m5: 6],
      j15: [m2: 6, m4: 10, m5: 8, m6: 6, m7: 6],
      j16: [m1: 6, m2: 5, m3: 9, m4: 4, m7: 6],
      j17: [m1: 4, m2: 9, m3: 10, m4: 14, m5: 12]
    }

    :observer.start()
    {:ok, pid} = ScheduleRunner.start_link(%{machines: machines, jobs: jobs, name: :schedule123})

    assert {:ok, _} = ScheduleRunner.start_scheduling(pid) |> IO.inspect()
  end
end
