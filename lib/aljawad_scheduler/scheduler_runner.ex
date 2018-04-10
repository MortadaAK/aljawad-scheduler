defmodule AljawadScheduler.ScheduleRunner do
  @moduledoc """
  A server that will handle the operations to prepare and generate the most
  optimize schedule.
  """
  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    SchedulerWorker,
    SchedulerWorkerSupervisor,
    SchedulerServer,
    SchedulerProducer,
    SchedulerConsumer
  }

  ## ETS

  @doc """
  returns the list of machines that is used in the schedule.
  """
  @spec machines(atom()) :: {:ok, map()} | {:error, :not_found}
  def machines(name) do
    get_value(name, "machines")
  end

  @doc """
  returns the all jobs that is going to be scheduled.
  """
  @spec jobs(atom()) :: {:ok, map()} | {:error, :not_found}
  def jobs(name) do
    get_value(name, "jobs")
  end

  @doc """
  returns the list of grouped jobs that is going to be scheduled separately.
  """
  @spec groups(atom()) :: {:ok, list(map())} | {:error, :not_found}
  def groups(name) do
    get_value(name, "groups")
  end

  @doc """
  returns the maximum number of hours that which the scheduling should stop at
  """
  @spec max(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def max(name, index) do
    get_value(name, "max_#{index}")
  end

  @doc """
  returns the sum of lag and waiting hours for the schedule that the scheduling
  should stop at
  """
  @spec wight(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def wight(name, index) do
    get_value(name, "wight_#{index}")
  end

  @doc """
  returns the sum of total number of possibilities for the groups
  """
  @spec total(atom()) :: {:ok, integer()} | {:error, :not_found}
  def total(name) do
    get_value(name, "total")
  end

  @doc """
  returns the sum of total number of possibilities for a group
  """
  @spec total(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def total(name, index) do
    get_value(name, "total_#{index}")
  end

  @doc """
  The selected most optimized schedules found yet and combine them into one
  """
  @spec current_schedule(atom()) :: map()
  def current_schedule(name) do
    {:ok, groups} = groups(name)

    for index <- 0..(Enum.count(groups) - 1) do
      get_value(name, "schedule_#{index}")
    end
    |> Enum.reduce(%{}, fn {:ok, schedule}, master_schedule ->
      Map.merge(schedule, master_schedule)
    end)
  end

  @doc """
  The selected most optimized schedule found yet for a group
  """
  @spec current_schedule(atom(), integer()) :: {:ok, map()} | {:error, :not_found}
  def current_schedule(name, index) do
    get_value(name, "schedule_#{index}")
  end

  @doc """
  Returns number of checked possibilities for all groups
  """
  @spec performed(atom()) :: {:ok, integer()} | {:error, :not_found}
  def performed(name) do
    get_value(name, "performed")
  end

  @doc """
  Returns number of checked possibilities for a groups
  """
  @spec performed(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def performed(name, index) do
    get_value(name, "performed_#{index}")
  end

  @doc """
  Sets the maximum number of running hours/minutes for the most optimized schedule
  """
  @spec set_max(atom(), integer(), integer()) :: :ok
  def set_max(name, index, max) do
    set_value(name, "max_#{index}", max)
  end

  @doc """
  Sets the minimum number of lag and waiting hours/minutes for the most
  optimized schedule
  """
  @spec set_wight(atom(), integer(), integer()) :: :ok
  def set_wight(name, index, wight) do
    set_value(name, "wight_#{index}", wight)
  end

  @spec set_total(atom(), integer()) :: :ok
  def set_total(name, total) do
    set_value(name, "total", total)
  end

  @spec set_total(atom(), integer(), integer()) :: :ok
  def set_total(name, index, total) do
    set_value(name, "total_#{index}", total)
  end

  @spec set_percentage(atom(), integer()) :: :ok
  def set_percentage(name, percentage) do
    set_value(name, "percentage", percentage)
  end

  def update_percentage(name) do
    case total(name) do
      {:ok, total} ->
        case performed(name) do
          {:ok, performed} ->
            set_value(name, "percentage", performed / total)

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def update_percentage(name, index) do
    case total(name, index) do
      {:ok, total} ->
        case performed(name, index) do
          {:ok, performed} ->
            set_value(name, "percentage_#{index}", performed / total)

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  @spec set_percentage(atom(), integer(), integer()) :: :ok
  def set_percentage(name, index, percentage) do
    set_value(name, "percentage_#{index}", percentage)
  end

  @spec set_performed(atom(), integer()) :: :ok
  def set_performed(name, performed) do
    set_value(name, "performed", performed)
  end

  @spec set_performed(atom(), integer(), integer()) :: :ok
  def set_performed(name, index, performed) when is_atom(name) and is_integer(index) do
    set_value(name, "performed_#{index}", performed)
  end

  @doc """
  Checks the new schedule is more optimized more than the previous one, if so, it set it otherwise will discard it.
  the checking process is:
  1- check the maximum that was found.
  2- if the new schedule will finish earlier than the optimized, it will be selected.
  3- if the new schedule and the previous one will finish at the same time,
  will check if the total (lag time * %25 + waiting time * %75) of the new
  schedule is less than than the previous one, then it will be selected.
  """
  @spec set_schedule(atom(), integer(), map()) :: {:ok, map()} | {:did_not_changed, map()}
  def set_schedule(name, index, schedule) when is_atom(name) and is_integer(index) do
    case check_schedule_and_set(schedule, name, index) do
      {:ok, schedule, max, wight} ->
        IO.puts(
          "#{Time.to_string(Time.utc_now())} Did change schedule(#{index}) period to #{max} and wight to #{
            wight
          }"
        )

        {:ok, schedule}

      {:did_not_changed} ->
        {:ok, schedule} = current_schedule(name, index)
        {:did_not_changed, schedule}
    end
  end

  @spec set_machines(atom(), map()) :: :ok
  def set_machines(name, machines) do
    set_value(name, "machines", machines)
  end

  @spec set_jobs(atom(), list()) :: :ok
  def set_jobs(name, jobs) do
    set_value(name, "jobs", jobs)
  end

  @spec set_groups(atom(), list()) :: :ok
  def set_groups(name, groups) do
    set_value(name, "groups", groups)
  end

  @spec set_value(atom(), String.t(), any()) :: :ok
  defp set_value(name, key, value) do
    :ets.insert(name, {key, value})
    :ok
  end

  @spec get_value(atom(), String.t()) :: {:ok, any()} | {:error, :not_found}
  defp get_value(name, key) do
    case :ets.lookup(name, key) do
      [{^key, value}] -> {:ok, value}
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Track total processes performed/skipped
  """
  def increment_performed(name, by) when is_integer(by) and is_atom(name) do
    :ets.update_counter(name, "performed", by)
    update_percentage(name)
  end

  def increment_performed(name, index, by) when is_integer(by) and is_atom(name) do
    :ets.update_counter(name, "performed_#{index}", by)
    update_percentage(name, index)
  end

  @doc """
  Setup ETS table to hold all information.
  """
  @spec setup_table(atom(), map(), map(), [map()]) :: :ok
  def setup_table(name, machines, jobs, groups) do
    :ets.new(name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

    groups
    |> Enum.map(&Enum.count/1)
    |> Enum.map(&Permutation.factorial/1)
    |> Enum.sum()
    |> (&set_total(name, &1)).()

    set_performed(name, 0)
    set_machines(name, machines)
    set_jobs(name, jobs)
    set_groups(name, groups)

    groups
    |> Enum.with_index()
    |> Enum.each(fn {group, index} ->
      set_max(name, index, 100_000_000)
      set_wight(name, index, 100_000_000)
      set_performed(name, index, 0)
      set_total(name, index, Permutation.factorial(Enum.count(group)))
    end)

    :ok
  end

  @doc """
  Starts the searching process for the optimized schedule. the process will do:
  1- split the jobs into groups where there will be no machine shared between
  them.
  2- build multiple schedules by mapping over jobs by selecting the positions
  first, 1/4, middle, 3/4, and last one then select the most optimized one.
  the search.
  3- start searching for the most optimized one from all possibilities.
  """
  @spec start_scheduling(atom()) :: map()
  def start_scheduling(name) do
    {:ok, machines} = ScheduleRunner.machines(name)
    {:ok, groups} = ScheduleRunner.groups(name)
    set_base_lines(name, groups, machines)

    # groups
    # |> Stream.with_index()
    # |> Stream.map(&SchedulerWorker.stream_jobs(name, &1, machines))
    # |> Enum.to_list()
    # groups
    # |> Enum.map(&Map.to_list/1)
    # |> Enum.with_index()
    # |> Enum.map(fn {[job | rest], index} ->
    #   Task.Supervisor.async(SchedulerWorkerSupervisor, fn ->
    #     {:ok, server} = SchedulerServer.start_link({name, index, machines, job, rest, 0})
    #     SchedulerServer.register(server)

    #     receive do
    #       :finished -> nil
    #     end
    #   end)
    # end)
    # |> Enum.map(&Task.await(&1, :infinity))
    groups
    |> Enum.map(&Map.to_list/1)
    |> Enum.with_index()
    |> Enum.map(fn {[job | rest], index} ->
      {:ok, producer} =
        GenStage.start_link(SchedulerProducer, {name, index, machines, job, rest, 0})

      {:ok, consumer01} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer02} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer03} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer04} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer05} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer06} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer07} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer08} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer09} = GenStage.start_link(SchedulerConsumer, :ok)
      {:ok, consumer10} = GenStage.start_link(SchedulerConsumer, :ok)

      GenStage.sync_subscribe(consumer01, to: producer)
      GenStage.sync_subscribe(consumer02, to: producer)
      GenStage.sync_subscribe(consumer03, to: producer)
      GenStage.sync_subscribe(consumer04, to: producer)
      GenStage.sync_subscribe(consumer05, to: producer)
      GenStage.sync_subscribe(consumer06, to: producer)
      GenStage.sync_subscribe(consumer07, to: producer)
      GenStage.sync_subscribe(consumer08, to: producer)
      GenStage.sync_subscribe(consumer09, to: producer)
      GenStage.sync_subscribe(consumer10, to: producer)
    end)

    Process.sleep(:infinity)

    current_schedule(name)
  end

  @doc """
  1- the machines will be considered as the base schedule.
  2- generate the groups
  """
  @spec init(%{machines: map(), jobs: list(), name: atom()}) :: {:ok, map()}
  def init(%{machines: machines, jobs: jobs, name: name}) do
    machines = Scheduler.prepare_machines(machines)
    groups = Scheduler.generate_groups(jobs)
    setup_table(name, machines, jobs, groups)

    for {group, index} <- Enum.with_index(groups) do
      Scheduler.schedule_jobs(
        machines,
        group,
        index
      )
      |> (&ScheduleRunner.set_schedule(name, index, &1)).()
    end

    {:ok,
     %{
       machines: machines,
       jobs: jobs,
       name: name
     }}
  end

  defp check_schedule_and_set(schedule, name, index) do
    new_max = Scheduler.get_max(schedule)
    new_lags = Scheduler.get_lags(schedule)
    new_waiting = Scheduler.get_waiting(schedule)

    {:ok, current_max} = ScheduleRunner.max(name, index)
    {:ok, current_wight} = ScheduleRunner.wight(name, index)
    new_wight = (new_lags * 0.25 + new_waiting * 0.75) |> round()
    max_reduced = new_max < current_max
    max_did_not_changed = new_max == current_max
    wight_reduced = current_wight > new_wight

    if max_reduced || (max_did_not_changed && wight_reduced) do
      set_max(name, index, new_max)
      set_wight(name, index, new_wight)
      set_value(name, "schedule_#{index}", schedule)

      {:ok, schedule, new_max, new_wight}
    else
      {:did_not_changed}
    end
  end

  defp set_base_lines(name, groups, machines) do
    groups
    |> Enum.with_index()
    |> Enum.each(fn {group, group_index} ->
      size = Permutation.factorial(Enum.count(group)) - 1

      Enum.reduce(1..(Enum.count(group) - 1), nil, fn i, selected ->
        [
          i * size,
          i * size + div(size, 4),
          i * size + div(size, 2),
          i * size + div(size * 3, 4),
          (i + 1) * size - 1
        ]
        |> Enum.reduce(selected, fn index, selected ->
          new_schedule =
            Scheduler.schedule_jobs(
              machines,
              group,
              index
            )

          case set_schedule(name, group_index, new_schedule) do
            {:ok, schedule} ->
              schedule

            _ ->
              selected
          end
        end)
      end)
    end)
  end
end
