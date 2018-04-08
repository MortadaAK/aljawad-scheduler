defmodule AljawadScheduler.SchedulerWorker do
  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    SchedulerWorker,
    SchedulerWorkerSupervisor
  }

  def stream_groups(name, groups, machines) do
    Task.Supervisor.async_stream(
      SchedulerWorkerSupervisor,
      Enum.with_index(groups),
      &stream_jobs(name, &1, machines),
      timeout: :infinity
    )
    |> Enum.to_list()
  end

  def stream_jobs(name, {jobs, index}, machines) do
    Task.Supervisor.async_stream(
      SchedulerWorkerSupervisor,
      jobs,
      &schedule_job(name, index, Map.to_list(jobs), &1, machines, 0),
      timeout: :infinity
    )
    |> Enum.to_list()
  end

  def schedule_job(name, index, jobs, job, machines, level) do
    rest_of_jobs = List.delete(jobs, job)

    SchedulerWorker.schedule(
      name,
      index,
      filter_machines(machines, jobs),
      job,
      rest_of_jobs,
      level
    )
  end

  @doc """
  Here the schedule got generated and all jobs scheduled except the last one.
  So, after the final job got added to the schedule, the schedule will be send
  as a proposed schedule.
  """
  def schedule(name, index, machines, {job, steps}, [], _) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)
    ScheduleRunner.set_schedule(name, index, new_schedule)
    ScheduleRunner.increment_performed(name, 1)
    ScheduleRunner.increment_performed(name, index, 1)
    0
  end

  @doc """
  Add a job to the schedule and compare the maximum hours required by adding the
  the required job to the maximum limit. if the hours is less than the maximum,
  a process will be generated for all possible candidate to be the next job to
  be scheduled. if the hours is exceeded the maximum or by adding these hours
  to the total hours that is required assuming that there will be no lags
  between then is greater than the maximum, then there is no point to continue
  in the search process.
  """
  def schedule(name, index, machines, {job, steps}, remaining_jobs, level) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)
    {:ok, max} = ScheduleRunner.max(name, index)

    if max > Scheduler.get_max(new_schedule) &&
         max > Scheduler.max_min_remaining(new_schedule, remaining_jobs) do
      if level > 3 do
        Task.Supervisor.async(SchedulerWorkerSupervisor, fn ->
          for next <- remaining_jobs do
            rest_of_jobs = List.delete(remaining_jobs, next)
            SchedulerWorker.schedule(name, index, new_schedule, next, rest_of_jobs, level + 1)
          end
        end)
        |> (&[&1]).()
        |> Enum.map(&Task.await(&1, :infinity))
      else
        Task.Supervisor.async_stream(
          SchedulerWorkerSupervisor,
          remaining_jobs,
          &schedule_job(name, index, remaining_jobs, &1, new_schedule, level + 1),
          timeout: :infinity
        )
        |> Enum.to_list()
        |> Enum.map(fn {:ok, count} -> count end)
      end
      |> List.flatten()
      |> Enum.sum()
    else
      skipped =
        remaining_jobs
        |> Enum.count()
        |> Permutation.factorial()

      ScheduleRunner.increment_performed(name, index, skipped)
      ScheduleRunner.increment_performed(name, skipped)

      skipped
    end
  end

  def filter_machines(machines, jobs) do
    machines_list =
      jobs
      |> Enum.map(fn {_job, operations} ->
        Enum.map(operations, fn {machine, _} ->
          machine
        end)
      end)
      |> List.flatten()
      |> Enum.uniq()

    Enum.filter(machines, fn {name, _} ->
      Enum.member?(machines_list, name)
    end)
    |> Enum.reduce(%{}, fn {machine, start}, machines ->
      Map.put(machines, machine, start)
    end)
  end
end
