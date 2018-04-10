defmodule AljawadScheduler.SchedulerConsumer do
  use GenStage

  alias AljawadScheduler.{
    SchedulerWorker,
    SchedulerProducer
  }

  def init(:ok) do
    {:consumer, :the_state_does_not_matter}
  end

  def handle_events([pid, list], _from, state) do
    list
    |> Enum.map(&schedule(pid, &1))

    {:noreply, [], state}
  end

  defp schedule(
         pid,
         {ets_index, {name, index, schedule, next_job, remaining_jobs, level}, "waiting"}
       ) do
    SchedulerProducer.increment(pid, "working", 1)
    SchedulerProducer.working(pid, ets_index)

    schedules = SchedulerWorker.schedule(name, index, schedule, next_job, remaining_jobs, level)

    SchedulerProducer.remove(
      pid,
      {ets_index, {name, index, schedule, next_job, remaining_jobs, level}}
    )

    SchedulerProducer.push(pid, schedules)
  end
end
