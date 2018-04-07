defmodule AljawadScheduler.SchedulerWorker do
  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    SchedulerWorker,
    SchedulerWorkerSupervisor
  }

  @doc """
  Here the schedule got generated and all jobs scheduled except the last one.
  So, after the final job got added to the schedule, the schedule will be send
  as a proposed schedule.
  """
  def schedule(pid, _name, machines, {job, steps}, [], _) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)
    ScheduleRunner.set_schedule(pid, new_schedule)
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
  def schedule(pid, name, machines, {job, steps}, remaining_jobs, level) do
    new_schedule = Scheduler.schedule_job(machines, job, steps)

    [{"max", max}] = :ets.lookup(name, "max")

    if max > Scheduler.get_max(new_schedule) &&
         max > Scheduler.max_min_remaining(new_schedule, remaining_jobs) do
      if level > 0 do
        Task.Supervisor.async(SchedulerWorkerSupervisor, fn ->
          for next <- remaining_jobs do
            rest_of_jobs = List.delete(remaining_jobs, next)
            SchedulerWorker.schedule(pid, name, new_schedule, next, rest_of_jobs, level + 1)
          end
        end)
        |> (&[&1]).()
      else
        for next <- remaining_jobs do
          Task.Supervisor.async(SchedulerWorkerSupervisor, fn ->
            rest_of_jobs = List.delete(remaining_jobs, next)

            SchedulerWorker.schedule(pid, name, new_schedule, next, rest_of_jobs, level + 1)
            |> (&[&1]).()
          end)
        end
      end
      |> Enum.map(&Task.await(&1, :infinity))
      |> List.flatten()
      |> Enum.sum()
    else
      remaining_jobs
      |> Enum.count()
      |> Permutation.factorial()
    end
  end
end
