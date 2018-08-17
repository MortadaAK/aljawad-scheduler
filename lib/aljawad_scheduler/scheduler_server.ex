defmodule AljawadScheduler.SchedulerServer do
  use GenServer

  alias AljawadScheduler.{
    SchedulerTask,
    ScheduleRunner,
    SchedulerSupervisor
  }

  @query [
    {
      ### THIS LINE CHANGED
      {:_},
      [],
      [:"$_"]
    }
  ]
  # Client

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def init(%{
        name: name,
        index: index,
        receiver: receiver,
        concurrent: concurrent,
        starting_range: range
      }) do
    queue =
      :ets.new(:scheduling_queue, [
        :ordered_set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    add_range(queue, range)

    {:ok,
     %{
       receiver: receiver,
       queue: queue,
       concurrent: concurrent,
       name: name,
       index: index,
       running: 0,
       stop: false
     }}
  end

  def add_ranges(pid, ranges) when is_pid(pid) do
    GenServer.cast(pid, {:add_ranges, ranges})
  end

  def stop_scheduling(pid) when is_pid(pid) do
    GenServer.cast(pid, :stop)
  end

  def start_scheduling(pid) do
    Process.send(pid, :run, [])
  end

  def add_range(queue, range = first..last) do
    :ets.insert(queue, {{first - last, range}})
  end

  def handle_info(:finished, state = %{receiver: receiver, running: 0, stop: true}) do
    send(receiver, {:finished, self()})
    {:stop, :normal, state}
  end

  def handle_info(:finished, state = %{receiver: receiver, name: name, index: index}) do
    {:ok, percentage} = ScheduleRunner.percentage(name, index)

    if percentage == 1.0 do
      send(receiver, {:finished, self()})
      {:stop, :normal, state}
    else
      {:noreply, schedule(state)}
    end
  end

  def handle_info(:run, state) do
    {:noreply, schedule(state)}
  end

  def handle_info({_pid, nil}, state = %{running: running}) do
    {:noreply, Map.put(state, :running, running - 1)}
  end

  def handle_info(
        {:DOWN, _from_pid, :process, _pid, :normal},
        state = %{running: running}
      )
      when running < 1 do
    {:noreply, schedule(state)}
  end

  def handle_info({:DOWN, _from_pid, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:noreply, Map.put(state, :stop, true)}
  end

  defp schedule(
         state = %{
           queue: queue,
           concurrent: concurrent
         }
       ) do
    # current_running = running()
    # count = max(concurrent - current_running, 0)
    count = 1

    queue
    |> next_ranges(count)
    |> (&schedule_ranges(state, &1)).()
  end

  defp running() do
    Supervisor.count_children(SchedulerSupervisor).active
  end

  defp schedule_ranges(state = %{stop: true}, _) do
    Process.send(self(), :finished, [])
    state
  end

  defp schedule_ranges(state, []) do
    Process.send(self(), :finished, [])
    state
  end

  defp schedule_ranges(
         state = %{name: name, index: index, queue: queue, running: running},
         ranges
       ) do
    for range <- ranges do
      Task.Supervisor.async(
        SchedulerSupervisor,
        SchedulerTask,
        :run,
        [
          name,
          index,
          queue,
          range
        ],
        restart: :transient
      )
    end

    state
    |> Map.put(:running, running + Enum.count(ranges))
  end

  defp next_ranges(_queue, count) when count < 1, do: []

  defp next_ranges(queue, count) do
    ranges =
      case :ets.select(queue, @query, count) do
        :"$end_of_table" ->
          []

        {ranges, _} ->
          ranges
          |> Enum.map(fn {record = {_size, range}} ->
            :ets.delete(queue, record)
            range
          end)
      end

    ranges
  end

  defp ets_count(queue) do
    :ets.select_count(queue, @query)
  end
end
