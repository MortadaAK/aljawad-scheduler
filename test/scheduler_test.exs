defmodule AljawadScheduler.SchedulerTest do
  use ExUnit.Case
  alias AljawadScheduler.Scheduler

  test "prepare machine schedule" do
    assert %{m1: {[s: 10], 10, 0, 0}} =
             %{m1: 10}
             |> Scheduler.prepare_machines()
  end

  test "add a job to a machine" do
    assert {%{m1: {[s: 10, j1: 5], 15, 0, 0}}, 15} ==
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

    assert %{m1: 14, m2: 9, m3: 2, m4: 21, m5: 17} == Scheduler.min_remaining(schedule, jobs)
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

    assert 21 == Scheduler.max_min_remaining(schedule, jobs)
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
            20} ==
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {15, 5})
  end

  test "add a job to a machine with a waiting" do
    assert {%{
              m1: {[s: 10, w: 5, j1: 5], 15, 0, 5}
            },
            15} ==
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
           ] == Scheduler.generate_groups(jobs)
  end

  test "multi layers groups" do
    jobs = %{
      j7: [m9: 2, m8: 2],
      j1: [m1: 2, m2: 2],
      j4: [m4: 2, m5: 2],
      j2: [m2: 2, m3: 2],
      j3: [m3: 2, m4: 2],
      j5: [m7: 2, m8: 2],
      j6: [m1: 2, m8: 2]
    }

    assert [
             %{
               j1: [m1: 2, m2: 2],
               j2: [m2: 2, m3: 2],
               j3: [m3: 2, m4: 2],
               j4: [m4: 2, m5: 2],
               j5: [m7: 2, m8: 2],
               j6: [m1: 2, m8: 2],
               j7: [m9: 2, m8: 2]
             }
           ] == Scheduler.generate_groups(jobs)
  end

  test "real jobs" do
    jobs = %{
      j25117: [m31: 62, m29: 62],
      j23903: [m31: 35, m29: 35],
      j24675: [m31: 482, m29: 482],
      j22975: [m31: 425, m29: 213],
      j25185: [m31: 32, m29: 32],
      j25029: [m31: 122, m29: 122],
      j25118: [m31: 93, m29: 93],
      j25134: [m29: 62, m24: 93],
      j25021: [m66: 360, m48: 845],
      j24719: [m4: 3263, m31: 350, m3: 1981],
      j25017: [m30: 365, m31: 61, m44: 304],
      j25425: [m29: 663, m66: 301, m20: 783],
      j25022: [m29: 182, m66: 122, m20: 244],
      j25089: [m3: 1502, m31: 603, m10: 7200],
      j25024: [m29: 140, m66: 122, m20: 214],
      j25102: [m31: 61, m2: 213, m7: 334],
      j25150: [m29: 44, m24: 65, m18: 87],
      j25153: [m29: 541, m24: 390, m18: 725],
      j25088: [m10: 7200, m31: 603, m3: 1502],
      j25155: [m29: 315, m24: 476, m48: 845],
      j25532: [m29: 362, m24: 242, m48: 423, m36: 242],
      j24672: [m66: 599, m48: 1714, m33: 1374, m37: 13736],
      j25218: [m29: 21, m24: 62, m20: 62, m40: 83],
      j25317: [m29: 32, m24: 96, m25: 128, m48: 96, m40: 159],
      j25275: [m24: 121, m29: 92, m48: 243, m62: 152, m45: 364],
      j25274: [m29: 122, m62: 183, m24: 244, m45: 853, m48: 488],
      j24738: [m29: 244, m24: 244, m51: 427, m19: 488, m39: 1218],
      j25318: [m29: 8, m24: 45, m36: 45, m17: 59, m25: 45],
      j24002: [m29: 32, m24: 96, m14: 318, m25: 96, m17: 96, m40: 128],
      j24427: [m19: 95, m66: 95, m31: 32, m61: 919, m54: 1014, m29: 32],
      j20332: [m31: 182, m29: 182, m23: 303, m18: 364, m61: 6111, m54: 6776],
      j24708: [m29: 30, m24: 90, m27: 90, m45: 150, m30: 181, m17: 3601],
      j24726: [m29: 62, m62: 62, m66: 92, m25: 123, m52: 92, m18: 153, m18: 153, m33: 368]
    }

    assert [
             %{
               j25117: [m31: 62, m29: 62],
               j23903: [m31: 35, m29: 35],
               j24675: [m31: 482, m29: 482],
               j22975: [m31: 425, m29: 213],
               j25185: [m31: 32, m29: 32],
               j25029: [m31: 122, m29: 122],
               j25118: [m31: 93, m29: 93],
               j25134: [m29: 62, m24: 93],
               j25021: [m66: 360, m48: 845],
               j24719: [m4: 3263, m31: 350, m3: 1981],
               j25017: [m30: 365, m31: 61, m44: 304],
               j25425: [m29: 663, m66: 301, m20: 783],
               j25022: [m29: 182, m66: 122, m20: 244],
               j25089: [m3: 1502, m31: 603, m10: 7200],
               j25024: [m29: 140, m66: 122, m20: 214],
               j25102: [m31: 61, m2: 213, m7: 334],
               j25150: [m29: 44, m24: 65, m18: 87],
               j25153: [m29: 541, m24: 390, m18: 725],
               j25088: [m10: 7200, m31: 603, m3: 1502],
               j25155: [m29: 315, m24: 476, m48: 845],
               j25532: [m29: 362, m24: 242, m48: 423, m36: 242],
               j24672: [m66: 599, m48: 1714, m33: 1374, m37: 13736],
               j25218: [m29: 21, m24: 62, m20: 62, m40: 83],
               j25317: [m29: 32, m24: 96, m25: 128, m48: 96, m40: 159],
               j25275: [m24: 121, m29: 92, m48: 243, m62: 152, m45: 364],
               j25274: [m29: 122, m62: 183, m24: 244, m45: 853, m48: 488],
               j24738: [m29: 244, m24: 244, m51: 427, m19: 488, m39: 1218],
               j25318: [m29: 8, m24: 45, m36: 45, m17: 59, m25: 45],
               j24002: [m29: 32, m24: 96, m14: 318, m25: 96, m17: 96, m40: 128],
               j24427: [m19: 95, m66: 95, m31: 32, m61: 919, m54: 1014, m29: 32],
               j20332: [m31: 182, m29: 182, m23: 303, m18: 364, m61: 6111, m54: 6776],
               j24708: [m29: 30, m24: 90, m27: 90, m45: 150, m30: 181, m17: 3601],
               j24726: [
                 m29: 62,
                 m62: 62,
                 m66: 92,
                 m25: 123,
                 m52: 92,
                 m18: 153,
                 m18: 153,
                 m33: 368
               ]
             }
           ] == Scheduler.generate_groups(jobs)
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
             } ==
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

      assert 25 == Scheduler.get_lags(schedule)
    end

    test "calculate sim of waiting hours" do
      schedule = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert 12 == Scheduler.get_waiting(schedule)
    end
  end
end
