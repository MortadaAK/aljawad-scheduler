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
    SchedulerWorkerSupervisor
  }

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
  # @spec max(atom()) :: {:ok, integer()} | {:error, :not_found}
  # def max(name) do
  #   get_value(name, "max")
  # end

  @spec max(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def max(name, index) do
    get_value(name, "max_#{index}")
  end

  @doc """
  returns the sum of lag and waiting hours for the schedule that the scheduling
  should stop at
  """
  # @spec wight(atom()) :: {:ok, integer()} | {:error, :not_found}
  # def wight(name) do
  #   get_value(name, "wight")
  # end

  @spec wight(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def wight(name, index) do
    get_value(name, "wight_#{index}")
  end

  @doc """
  returns the total number of possibilities for based on the jobs
  """
  @spec total(atom()) :: {:ok, integer()} | {:error, :not_found}
  def total(name) do
    get_value(name, "total")
  end

  @doc """
  The selected most optimized schedule found yet
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

  @spec current_schedule(atom(), integer()) :: {:ok, map()} | {:error, :not_found}
  def current_schedule(name, index) do
    get_value(name, "schedule_#{index}")
  end

  @doc """
  Returns number of performed processes
  """
  @spec performed(atom()) :: {:ok, integer()} | {:error, :not_found}
  def performed(name) do
    get_value(name, "performed")
  end

  @spec performed(atom(), integer()) :: {:ok, integer()} | {:error, :not_found}
  def performed(name, index) do
    get_value(name, "performed_#{index}")
  end

  @doc """
  Setup ETS table to hold all information.
  """
  @spec setup_table(atom(), map(), map(), [map()]) :: :ok
  def setup_table(name, machines, jobs, groups) do
    :ets.new(name, [:named_table, :set, :public, read_concurrency: true])

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

  # @spec set_max(atom(), integer()) :: :ok
  # def set_max(name, max) do
  #   set_value(name, "max", max)
  # end

  @spec set_max(atom(), integer(), integer()) :: :ok
  def set_max(name, index, max) do
    set_value(name, "max_#{index}", max)
  end

  # @spec set_wight(atom(), integer()) :: :ok
  # def set_wight(name, wight) do
  #   set_value(name, "wight", wight)
  # end

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

  @spec set_performed(atom(), integer()) :: :ok
  def set_performed(name, performed) do
    set_value(name, "performed", performed)
  end

  @spec set_performed(atom(), integer(), integer()) :: :ok
  def set_performed(name, index, performed) when is_atom(name) and is_integer(index) do
    set_value(name, "performed_#{index}", performed)
  end

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
  end

  def increment_performed(name, index, by) when is_integer(by) and is_atom(name) do
    :ets.update_counter(name, "performed_#{index}", by)
  end

  @doc """
  Starts the searching process for the optimized schedule. the process will do:
  1- build multiple schedules by mapping over jobs and allowing them to be the
  first job to run. then select the most optimized one the be the base line for
  the search.
  2- Go over all jobs and create a process that will search for an optimized
  schedule that start with the selected job as the first one to run.
  """
  @spec start_scheduling(atom()) :: map()
  def start_scheduling(name) do
    {:ok, machines} = ScheduleRunner.machines(name)
    {:ok, groups} = ScheduleRunner.groups(name)

    name
    |> SchedulerWorker.stream_groups(groups, machines)

    current_schedule(name)
  end

  @spec init(%{machines: map(), jobs: list(), name: atom()}) :: {:ok, map()}
  def init(%{machines: machines, jobs: jobs, name: name}) do
    machines = Scheduler.prepare_machines(machines)
    groups = Scheduler.generate_groups(jobs)
    setup_table(name, machines, jobs, groups)

    set_base_lines(name, groups, machines)

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
      size = Permutation.factorial(Enum.count(group) - 1)

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
              SchedulerWorker.filter_machines(machines, group),
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
