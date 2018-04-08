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

  test "generate groups of jobs which there is no shared machine between them" do
    jobs = %{
      j1: [m1: 2, m2: 2, m4: 2],
      j2: [m3: 2, m5: 2, m6: 2],
      j3: [m3: 2, m6: 2, m7: 2],
      j4: [m4: 2, m8: 2, m9: 2]
    }

    assert [
             %{j2: [m3: 2, m5: 2, m6: 2], j3: [m3: 2, m6: 2, m7: 2]},
             %{j1: [m1: 2, m2: 2, m4: 2], j4: [m4: 2, m8: 2, m9: 2]}
           ] = Scheduler.generate_groups(jobs)
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
