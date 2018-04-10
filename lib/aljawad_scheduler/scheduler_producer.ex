defmodule AljawadScheduler.SchedulerProducer do
  use GenStage

  def init({name, index, schedule, next_job, rest_of_jobs, level}) do
    counter = :ets.new(:counter, [])
    data = :ets.new(:data, [])
    :ets.insert(counter, {"count", 0})
    :ets.insert(counter, {"working", 0})
    :ets.insert(counter, {"waiting", 0})
    insert(counter, data, {name, index, schedule, next_job, rest_of_jobs, level})

    {:producer, {counter, data}}
  end

  def push(pid, schedules) do
    GenServer.cast(pid, {:push, schedules})
  end

  def remove(pid, schedule) do
    GenServer.cast(pid, {:remove, schedule})
  end

  def increment(pid, type, by) when is_pid(pid) do
    GenServer.cast(pid, {:increment, type, by})
  end

  def working(pid, schedule_index) do
    GenServer.cast(pid, {:working, schedule_index})
  end

  def handle_demand(demand, {counter, data}) when demand > 0 do
    query = [
      {
        {:_, {:_, :_, :_, :_, :_, :"$2"}, :"$1"},
        [
          {:andalso, {:==, :"$1", "waiting"}}
        ],
        [:"$_"]
      }
    ]

    group =
      case :ets.select(data, query, demand) do
        {match, _} -> match
        :"$end_of_table" -> []
      end

    {:noreply, [self(), group], {counter, data}}
  end

  def handle_cast({:increment, type, by}, state = {counter, _data}) do
    increment(counter, type, by)
    {:noreply, [], state}
  end

  def handle_cast({:working, schedule_index}, state = {_counter, data}) do
    :ets.update_element(data, schedule_index, {3, "working"})
    {:noreply, [], state}
  end

  def handle_cast(
        {:remove, {index, schedule}},
        status = {counter, data}
      ) do
    remove(counter, data, {index, schedule})

    {:noreply, [], status}
  end

  def handle_cast({:push, []}, state) do
    {:noreply, [], state}
  end

  def handle_cast({:push, schedules}, status = {counter, data}) do
    Enum.map(schedules, fn s -> insert(counter, data, s) end)

    {:noreply, [], status}
  end

  # ETS
  defp insert(counter, data, schedule) do
    count = increment(counter, "count", 1)
    increment(counter, "waiting", 1)
    :ets.insert(data, {count, schedule, "waiting"})
  end

  defp count(counter, type) do
    [{^type, count}] = :ets.lookup(counter, type)
    count
  end

  defp remove(counter, data, {index, schedule}) do
    :ets.delete_object(data, {index, schedule})
    increment(counter, "working", -1)
  end

  def increment(counter, type, by) do
    :ets.update_counter(counter, type, by)
  end
end
