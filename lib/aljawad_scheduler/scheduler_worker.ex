defmodule AljawadScheduler.SchedulerWorker do
  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    SchedulerWorker
    # SchedulerWorkerSupervisor
  }

  def stream_jobs(name, index, jobs, schedule) do
    # {:ok, current} = ScheduleRunner.current_working(name)

    Task.async_stream(
      jobs,
      &schedule_job(name, index, jobs, &1, schedule),
      timeout: :infinity
    )
    |> Enum.to_list()
    |> Enum.map(fn v ->
      case v do
        {:ok, nil} -> nil
        {:ok, result} -> result
      end
    end)
    |> Enum.filter(&(&1 != nil))
  end

  def schedule_job(name, index, jobs, job, machines) do
    rest_of_jobs = List.delete(jobs, job)

    SchedulerWorker.schedule(
      name,
      index,
      machines,
      job,
      rest_of_jobs
    )
  end

  @doc """
  Here the schedule got generated and all jobs scheduled except the last one.
  So, after the final job got added to the schedule, the schedule will be send
  as a proposed schedule.
  """
  def schedule(name, index, machines, {job, steps}, []) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)
    ScheduleRunner.set_schedule(name, index, new_schedule)
    ScheduleRunner.increment_performed(name, 1)
    ScheduleRunner.increment_performed(name, index, 1)
    nil
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
  def schedule(name, index, machines, {job, steps}, remaining_jobs) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)

    if should_continue?(name, index, new_schedule, remaining_jobs) do
      {name, index, remaining_jobs, new_schedule}
    else
      increment_performed(name, index, remaining_jobs)
      nil
    end
  end

  defp increment_performed(name, index, remaining_jobs) do
    skipped =
      remaining_jobs
      |> Enum.count()
      |> Permutation.factorial()

    ScheduleRunner.increment_performed(name, index, skipped)
    ScheduleRunner.increment_performed(name, skipped)
  end

  defp should_continue?(name, index, new_schedule, remaining_jobs) do
    {:ok, max} = ScheduleRunner.max(name, index)

    max > Scheduler.get_max(new_schedule) &&
      max > Scheduler.max_min_remaining(new_schedule, remaining_jobs)
  end
end
