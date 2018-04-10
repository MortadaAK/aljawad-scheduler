defmodule AljawadScheduler.QueueScheduler do
  use GenServer

  # Client

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def delete(pid, schedules) when is_pid(pid) do
    GenServer.cast(pid, {:delete_scheduled, schedules})
  end

  def push(pid, schedules) do
    GenServer.cast(pid, {:push, schedules})
  end

  def next(pid, count \\ 5000) do
    GenServer.call(pid, {:next, count}, :infinity)
  end

  # Server (callbacks)

  def init({jobs, schedule}) do
    data = :ets.new(:schedules_queue, [:set])
    counter = :ets.new(:schedules_counter, [:set])
    :ets.insert(counter, {"counter", 0})
    state = %{data: data, counter: counter}
    insert(state, {jobs, schedule})
    {:ok, state}
  end

  def handle_call({:next, count}, _from, state) do
    # count = min(:queue.len(queue), 2500)
    # {front, remaining} = :queue.split(count, queue)
    # count = min(:queue.len(remaining), 3500)

    # {back, remaining} =
    #   remaining
    #   |> :queue.reverse()
    #   |> (&:queue.split(count, &1)).()

    # list = :queue.join(front, back) |> :queue.to_list()

    {:reply, {:ok, next_schedules(state, count)}, state}
  end

  def handle_cast({:delete_scheduled, schedules}, state) do
    delete_scheduled(state, schedules)

    {:noreply, state}
  end

  def handle_cast({:push, schedules}, state) do
    Enum.each(schedules, fn schedule ->
      insert(state, schedule)
    end)

    {:noreply, state}
  end

  defp next_serial(%{counter: counter}) do
    :ets.update_counter(counter, "counter", 1)
  end

  defp insert(state = %{data: data, counter: _counter}, {jobs, schedule}) do
    :ets.insert(data, {next_serial(state), {jobs, schedule}})
  end

  defp next_schedules(%{data: data}, count) do
    query = [
      {
        {:_, :_},
        [],
        [:"$_"]
      }
    ]

    case :ets.select(data, query, count) do
      :"$end_of_table" -> []
      {result, _} -> result
    end
  end

  defp delete_scheduled(%{data: data}, schedules) do
    for {index, _} <- schedules do
      :ets.delete(data, index)
    end
  end
end
