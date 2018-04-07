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
