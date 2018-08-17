defmodule AljawadScheduler.SchedulerTask do
  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    Scheduler,
    SchedulerServer,
    SchedulerTask,
    SchedulerServer
  }

  def run(name, index, queue, range = first..last) do
    {:ok, group} = ScheduleRunner.group(name, index)
    count = Enum.count(group)
    {:ok, schedule} = ScheduleRunner.machines(name, index)
    {:ok, base} = Permutation.base(first..last, count)
    jobs = Permutation.create_permutation(group, first)

    scheduled_jobs =
      jobs
      |> Enum.take(count - base)

    remaining_jobs =
      jobs
      |> Enum.take(1 - base)

    SchedulerTask.run_schedule(
      name,
      index,
      group,
      queue,
      range,
      schedule,
      scheduled_jobs,
      remaining_jobs
    )

    nil
  end

  @doc """
  Here the schedule got generated and all jobs scheduled except the last one.
  So, after the final job got added to the schedule, the schedule will be send
  as a proposed schedule.
  """
  def run_schedule(name, index, _group, _queue, _range, schedule, jobs, []) do
    new_schedule = Scheduler.schedule_jobs(schedule, jobs)
    ScheduleRunner.set_schedule(name, index, new_schedule)
    ScheduleRunner.increment_performed(name, 1)
    ScheduleRunner.increment_performed(name, index, 1)
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
  def run_schedule(name, index, group, queue, range, schedule, jobs, remaining_jobs) do
    new_schedule = Scheduler.schedule_jobs(schedule, jobs)

    if should_continue?(name, index, new_schedule, remaining_jobs) do
      {:ok, new_ranges} = Permutation.expand(range)
      add_ranges(queue, new_ranges)
      check_others(name, index, group, schedule, range)
    else
      increment_performed(name, index, remaining_jobs)
    end
  end

  defp increment_performed(name, index, remaining_jobs) do
    skipped =
      [1 | remaining_jobs]
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

  defp add_ranges(queue, ranges) do
    Enum.each(ranges, fn range ->
      SchedulerServer.add_range(queue, range)
    end)
  end

  def check_others(name, index, group, schedule, first..last) do
    # we are going to try this schedule to see if we can reduce the possibilities by it.
    size = last - first

    [
      first,
      first + div(size, 6),
      first + div(size, 3),
      first + div(size, 2),
      first + div(size * 2, 3),
      first + div(size * 5, 6),
      last
    ]
    |> Enum.uniq()
    |> Enum.map(fn i ->
      jobs = Permutation.create_permutation(group, i)
      new_schedule = Scheduler.schedule_jobs(schedule, jobs)
      ScheduleRunner.set_schedule(name, index, new_schedule)
    end)
  end
end
