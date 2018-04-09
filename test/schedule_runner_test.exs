defmodule AljawadScheduler.ScheduleRunnerTest do
  use ExUnit.Case

  alias AljawadScheduler.{ScheduleRunner, SchedulerWorker}

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

  test "initialize with machines", args = %{name: name} do
    assert {:ok, _} = ScheduleRunner.init(args)

    assert {:ok,
            %{
              m1: {[s: 10], 10, 0, 0},
              m2: {[s: 5], 5, 0, 0},
              m3: {[s: 0], 0, 0, 0},
              m4: {[s: 15], 15, 0, 0}
            }} = ScheduleRunner.machines(name)
  end

  test "initialize with jobs", args = %{jobs: jobs, name: name} do
    assert {:ok, _} = ScheduleRunner.init(args)

    assert {:ok, ^jobs} = ScheduleRunner.jobs(name)
  end

  test "generate groups of jobs" do
    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m2: 3, m3: 6, m4: 2],
      j3: [m5: 2, m6: 4, m7: 1],
      j4: [m6: 2, m7: 2, m8: 1]
    }

    machines = %{m1: 0, m2: 0, m3: 0, m4: 0, m5: 0, m6: 0, m7: 0, m8: 0}
    name = :grouped_jobs
    assert {:ok, _} = ScheduleRunner.init(%{jobs: jobs, machines: machines, name: name})

    assert {:ok, ^jobs} = ScheduleRunner.jobs(name)

    assert {:ok,
            [
              %{j1: [m1: 2, m2: 2, m4: 6], j2: [m2: 3, m3: 6, m4: 2]},
              %{j3: [m5: 2, m6: 4, m7: 1], j4: [m6: 2, m7: 2, m8: 1]}
            ]} = ScheduleRunner.groups(name)
  end

  test "should setup ets table", args = %{name: name} do
    assert {:ok, _} = ScheduleRunner.init(args)
    assert {:ok, 24} = ScheduleRunner.total(name)
    assert {:ok, 0} = ScheduleRunner.performed(name)
    assert {:ok, _} = ScheduleRunner.wight(name, 0)
    assert {:ok, _} = ScheduleRunner.max(name, 0)
  end

  test "should update performed", args = %{name: name} do
    assert {:ok, _} = ScheduleRunner.init(args)
    assert {:ok, 0} = ScheduleRunner.performed(name)
    ScheduleRunner.increment_performed(name, 1)
    assert {:ok, 1} = ScheduleRunner.performed(name)
  end

  test "initialize with first schedule", args = %{name: name} do
    assert {:ok, _} = ScheduleRunner.init(args)

    assert {:ok, 27} = ScheduleRunner.max(name, 0)

    assert {:ok,
            %{
              m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
              m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
              m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
              m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
            }} = ScheduleRunner.current_schedule(name, 0)
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

    {:ok, _} = ScheduleRunner.init(%{machines: machines, jobs: jobs, name: :schedule123})

    assert %{
             m1: {[s: 10, j2: 3, j1: 2, j4: 2, j5: 4], 21, 0, 0},
             m2: {[s: 5, l: 10, j1: 2, j3: 2, w: 2, j4: 2], 21, 10, 2},
             m3: {[s: 0, j6: 6, l: 7, j2: 6, j3: 4, w: 2, j4: 1, l: 9, j5: 16], 49, 16, 2},
             m4:
               {[s: 15, w: 9, j6: 12, w: 8, j2: 2, w: 12, j1: 6, w: 12, j3: 1, w: 12, j4: 1], 37,
                0, 53},
             m5: {[s: 5, l: 22, j6: 16], 43, 22, 0},
             m6: {[s: 2, l: 19, j5: 12], 33, 19, 0},
             m7: {[s: 20, l: 23, j6: 6, j5: 6], 55, 23, 0}
           } = ScheduleRunner.start_scheduling(:schedule123)
  end

  test "schedule each group" do
    machines = %{m1: 10, m2: 5, m3: 0, m4: 15, m5: 5, m6: 2, m7: 20, m8: 5}

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m1: 3, m3: 6, m4: 2],
      j3: [m2: 2, m3: 4, m4: 1],
      j4: [m5: 2, m6: 2, m7: 1],
      j5: [m5: 4, m7: 16, m8: 6],
      j6: [m6: 6, m7: 12, m8: 16]
    }

    name = :schedule123
    {:ok, _} = ScheduleRunner.init(%{machines: machines, jobs: jobs, name: name})
    assert :timer.tc(fn -> ScheduleRunner.start_scheduling(name) end) |> IO.inspect()

    assert {:ok,
            [
              %{
                j1: [m1: 2, m2: 2, m4: 6],
                j2: [m1: 3, m3: 6, m4: 2],
                j3: [m2: 2, m3: 4, m4: 1]
              },
              %{
                j4: [m5: 2, m6: 2, m7: 1],
                j5: [m5: 4, m7: 16, m8: 6],
                j6: [m6: 6, m7: 12, m8: 16]
              }
            ]} = ScheduleRunner.groups(name)

    assert {:ok,
            %{
              m1: {[s: 10, j1: 2, j2: 3], 15, 0, 0},
              m2: {[s: 5, j3: 2, l: 5, j1: 2], 14, 5, 0},
              m3: {[s: 0, l: 7, j3: 4, l: 4, j2: 6], 21, 11, 0},
              m4: {[s: 15, w: 4, j3: 1, w: 2, j1: 6, w: 1, j2: 2], 24, 0, 7}
            }} = ScheduleRunner.current_schedule(name, 0)

    assert {:ok,
            %{
              m5: {[s: 5, j5: 4, j4: 2], 11, 0, 0},
              m6: {[s: 2, j6: 6, l: 3, j4: 2], 13, 3, 0},
              m7: {[s: 20, w: 12, j6: 12, w: 23, j5: 16, w: 35, j4: 1], 49, 0, 70},
              m8: {[s: 5, l: 27, j6: 16, j5: 6], 54, 27, 0}
            }} = ScheduleRunner.current_schedule(name, 1)
  end

  # @tag timeout: :infinity
  # test "schedule all (v17)" do
  #   machines = %{m1: 0, m2: 0, m3: 0, m4: 0, m5: 0, m6: 0, m7: 0}

  #   jobs = %{
  #     j1: [m1: 2, m2: 2, m4: 6],
  #     j2: [m1: 6, m3: 6, m4: 2],
  #     j3: [m2: 2, m3: 4, m4: 1],
  #     j4: [m1: 4, m2: 2, m3: 1, m4: 1],
  #     j5: [m1: 4, m6: 12, m3: 16, m7: 6],
  #     j6: [m3: 6, m4: 12, m5: 10, m7: 6],
  #     j7: [m2: 3, m4: 5, m7: 10, m6: 7],
  #     j8: [m1: 12, m4: 5, m7: 10, m6: 6],
  #     j9: [m1: 3, m2: 15, m5: 14, m7: 15],
  #     j10: [m1: 3, m4: 5, m6: 10, m7: 8],
  #     j11: [m1: 13, m2: 6, m4: 5, m3: 5, m6: 10, m7: 6],
  #     j12: [m2: 3, m2: 3, m4: 5, m3: 15, m7: 6],
  #     j13: [m2: 12, m3: 5, m4: 10, m7: 8],
  #     j14: [m1: 6, m2: 6, m3: 12, m4: 12, m5: 6],
  #     j15: [m2: 6, m4: 10, m5: 8, m6: 6, m7: 6],
  #     j16: [m1: 6, m2: 5, m3: 9, m4: 4, m7: 6],
  #     j17: [m1: 4, m2: 9, m3: 10, m4: 14, m5: 12]
  #   }

  #   :observer.start()
  #   {:ok, _} = ScheduleRunner.init(%{machines: machines, jobs: jobs, name: :schedule123})

  #   assert _ = ScheduleRunner.start_scheduling(:schedule123)
  # end

  @tag timeout: :infinity
  test "schedule all (v30)" do
    machines = %{}

    jobs = %{
      j26036: [m2105: 15, m2103: 15],
      j26038: [m2105: 29, m2103: 41, m2411: 61, m2411: 8],
      j25669: [m2222: 2, m2411: 3, m2502: 3],
      # j25546: [m2105: 2, m2214: 3, m2906: 1],
      # j25829: [m2103: 2, m2222: 1, m2405: 2, m2503: 6],
      # j25827: [m2105: 1, m2214: 2, m2906: 3],
      # j25828: [m2105: 1, m2214: 2, m2904: 3],
      # j25906: [m2105: 2, m2214: 4, m2904: 6],
      j25911: [m2105: 4, m2214: 6, m2904: 2],
      j25926: [m2105: 3, m2103: 5, m2225: 5, m2301: 8, m2411: 7, m2508: 7],
      j25503: [m2103: 2, m2222: 2, m2301: 3, m2411: 3, m2303: 6, m2502: 4],
      j25886: [m2103: 1, m2222: 2, m2405: 2, m2503: 3],
      j25739: [m11002: 1, m12104: 2, m15101: 2],
      j25895: [m12501: 5, m12502: 14],
      j25712: [m11002: 1, m12106: 2, m12201: 2, m13102: 2],
      j25832: [m2103: 2, m2222: 3, m2405: 3, m2508: 3],
      j25737: [m2405: 5, m2502: 5],
      j25820: [m2103: 2, m2222: 3, m2405: 2, m2502: 2],
      j25854: [m2103: 3, m2409: 4],
      j25640: [m2103: 1, m2222: 2, m2405: 3, m2508: 4],
      j25785: [m2103: 2, m2222: 2, m2411: 3, m2502: 2],
      j25646: [m2105: 2, m2103: 2, m2222: 3, m2405: 3, m2502: 4],
      j25645: [m2103: 1, m2222: 1, m2406: 2, m2502: 3],
      j25647: [m2103: 2, m2222: 3, m2405: 4, m2502: 4],
      j25639: [m11002: 1, m12104: 17, m14101: 11, m15101: 40],
      j25617: [m2103: 3, m2222: 0, m2309: 6, m2405: 6, m2508: 6],
      j25557: [m2103: 1, m2222: 2, m2411: 3, m2502: 2],
      j25556: [m2103: 1, m2405: 3, m2502: 2],
      j25757: [m2105: 2, m2103: 2, m2225: 2, m2405: 3, m2811: 57, m2821: 57],
      j25745: [m2103: 2, m2913: 3, m2222: 3, m2304: 4, m2409: 4],
      j25320: [m2103: 1, m2913: 2, m2225: 2, m2304: 4, m2405: 3],
      j25321: [m2103: 1, m2913: 2, m2225: 2, m2304: 3, m2411: 2],
      j25578: [m2103: 2, m2211: 4, m2309: 5, m2218: 11, m2405: 4, m2502: 4]
      # j25564: [m2105: 2, m2214: 12, m2908: 10],
      # j25701: [m2103: 2, m2913: 2, m2222: 2, m2310: 2, m2409: 3]
    }

    :observer.start()
    {:ok, _} = ScheduleRunner.init(%{machines: machines, jobs: jobs, name: :schedule123})

    assert _ = ScheduleRunner.start_scheduling(:schedule123)
  end

  @tag timeout: :infinity
  test "real example" do
    machines = %{
      m10: 0,
      m14: 0,
      m17: 0,
      m18: 0,
      m19: 0,
      m2: 0,
      m20: 0,
      m23: 0,
      m24: 0,
      m25: 0,
      m27: 0,
      m29: 0,
      m3: 0,
      m30: 0,
      m31: 0,
      m33: 0,
      m36: 0,
      m37: 0,
      m39: 0,
      m4: 0,
      m40: 0,
      m44: 0,
      m45: 0,
      m48: 0,
      m51: 0,
      m52: 0,
      m54: 0,
      m61: 0,
      m62: 0,
      m66: 0,
      m68: 0,
      m7: 0
    }

    jobs = %{
      # j25117: [m31: 62, m29: 62],
      # j23903: [m31: 35, m29: 35],
      # j24675: [m31: 482, m29: 482],
      # j22975: [m31: 425, m29: 213],
      # j25185: [m31: 32, m29: 32],
      # j25029: [m31: 122, m29: 122],
      # j25118: [m31: 93, m29: 93],
      # j25134: [m29: 62, m24: 93],
      # j25021: [m66: 360, m48: 845],
      # j24719: [m4: 3263, m31: 350, m3: 1981],
      # j25017: [m30: 365, m31: 61, m44: 304],
      # j25425: [m29: 663, m66: 301, m20: 783],
      # j25022: [m29: 182, m66: 122, m20: 244],
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

    :observer.start()
    name = :schedule123
    ScheduleRunner.init(%{machines: machines, jobs: jobs, name: name})
    ScheduleRunner.groups(name)
    # assert {:ok, _} =
    ScheduleRunner.start_scheduling(name)
  end
end
