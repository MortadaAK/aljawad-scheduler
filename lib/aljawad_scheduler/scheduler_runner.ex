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

  use GenServer

  # Client

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  @doc """
  returns the list of machines that is used in the schedule.
  """
  @spec machines(pid()) :: {:ok, map()}
  def machines(pid) do
    GenServer.call(pid, :machines)
  end

  @doc """
  returns the name of the ets table that is going to be used to store the
  maximum number of hours that which the scheduling should stop at
  """
  @spec name(pid()) :: {:ok, atom()}
  def name(pid) do
    GenServer.call(pid, :name)
  end

  @doc """
  returns the list of jobs that is going to be scheduled.
  """
  @spec jobs(pid) :: {:ok, list()}
  def jobs(pid) do
    GenServer.call(pid, :jobs)
  end

  @doc """
  returns the maximum number of hours that which the scheduling should stop at
  """
  @spec max(pid) :: {:ok, integer()}
  def max(pid) do
    GenServer.call(pid, :max, :infinity)
  end

  @doc """
  The selected most optimized schedule found yet
  """
  @spec current_schedule(pid) :: {:ok, map()}
  def current_schedule(pid) do
    GenServer.call(pid, :current_schedule, :infinity)
  end

  @doc """
  propose a schedule to be the optimized one
  """
  def set_schedule(pid, schedule) do
    GenServer.cast(pid, {:current_schedule, schedule})
  end

  @doc """
  Starts the searching process for the optimized schedule. the process will do:
  1- build multiple schedules by mapping over jobs and allowing them to be the
  first job to run. then select the most optimized one the be the base line for
  the search.
  2- Go over all jobs and create a process that will search for an optimized
  schedule that start with the selected job as the first one to run.
  """
  def start_scheduling(pid) do
    {:ok, jobs} = ScheduleRunner.jobs(pid)
    {:ok, machines} = ScheduleRunner.machines(pid)
    {:ok, name} = ScheduleRunner.name(pid)
    jobs_list = Map.to_list(jobs)

    count =
      jobs_list
      |> Enum.reduce([], fn job, tasks ->
        [
          Task.Supervisor.async(SchedulerWorkerSupervisor, fn ->
            rest_of_jobs = List.delete(jobs_list, job)
            SchedulerWorker.schedule(pid, name, machines, job, rest_of_jobs, 0)
          end)
          | tasks
        ]
      end)
      |> Enum.map(&Task.await(&1, :infinity))
      |> Enum.sum()

    total_count = Permutation.factorial(Enum.count(jobs))
    performed = total_count - count
    percentage = performed / total_count
    skipped_percentage = count / total_count
    IO.puts("Total Performed #{performed} (% #{percentage})")
    IO.puts("Total Skipped #{count} (% #{skipped_percentage})")

    current_schedule(pid)
  end

  # Server (callbacks)

  def init(%{machines: machines, jobs: jobs, name: name}) do
    machines = Scheduler.prepare_machines(machines)
    :ets.new(name, [:named_table, :set, :protected, read_concurrency: true])
    :ets.insert(name, {"max", 100_000_000})
    :ets.insert(name, {"wight", 100_000_000})

    size = Permutation.factorial(Enum.count(jobs) - 1)
    # select first, middle, last of each branch
    selected =
      Enum.reduce(1..(Enum.count(jobs) - 1), nil, fn i, selected ->
        [
          i * size,
          i * size + div(size, 4),
          i * size + div(size, 2),
          i * size + div(size * 3, 4),
          (i + 1) * size - 1
        ]
        |> Enum.reduce(selected, fn index, selected ->
          new_schedule = Scheduler.schedule_jobs(machines, jobs, index)

          case check_schedule(new_schedule, name) do
            {:ok, schedule, _new_max, _new_wight} ->
              schedule

            _ ->
              selected
          end
        end)
      end)

    {:ok,
     %{
       machines: machines,
       jobs: jobs,
       current_schedule: selected,
       name: name
     }}
  end

  def handle_call(:jobs, _from, t) do
    {:reply, {:ok, t.jobs}, t}
  end

  def handle_call(:name, _from, t) do
    {:reply, {:ok, t.name}, t}
  end

  def handle_call(:max, _from, t) do
    max =
      case :ets.lookup(t.name, "max") do
        [{"max", max}] -> max
        _ -> 1_000_000
      end

    {:reply, {:ok, max}, t}
  end

  def handle_call(:machines, _from, t) do
    {:reply, {:ok, t.machines}, t}
  end

  def handle_call(:current_schedule, _from, t) do
    {:reply, {:ok, t.current_schedule}, t}
  end

  def handle_cast(
        {:current_schedule, next_schedule},
        state = %{name: name}
      ) do
    case check_schedule(next_schedule, name) do
      {:ok, schedule, max, wight} ->
        :ets.insert(name, {"max", max})
        :ets.insert(name, {"wight", wight})

        IO.puts(
          "#{Time.to_string(Time.utc_now())} Did change schedule period to #{max} and wight to #{
            wight
          }"
        )

        {
          :noreply,
          state
          |> Map.put(:max, max)
          |> Map.put(:current_schedule, schedule)
        }

      {:no_change} ->
        {:noreply, state}
    end
  end

  defp check_schedule(schedule, name) do
    new_max = Scheduler.get_max(schedule)
    new_lags = Scheduler.get_lags(schedule)
    new_waiting = Scheduler.get_waiting(schedule)

    [{"max", current_max}] = :ets.lookup(name, "max")
    [{"wight", current_wight}] = :ets.lookup(name, "wight")
    new_wight = new_lags * 0.25 + new_waiting * 0.75
    max_reduced = new_max < current_max
    max_not_changed = new_max == current_max
    wight_reduced = current_wight >= new_wight

    if max_reduced || (max_not_changed && wight_reduced) do
      :ets.insert(name, {"max", new_max})
      :ets.insert(name, {"wight", new_wight})

      {:ok, schedule, new_max, new_wight}
    else
      {:no_change}
    end
  end
end
