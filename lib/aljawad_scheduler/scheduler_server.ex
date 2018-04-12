defmodule AljawadScheduler.SchedulerServer do
  use GenServer

  alias AljawadScheduler.{
    SchedulerTask,
    SchedulerSupervisor
  }

  @concurrent 25000
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
        receiver: receiver
      }) do
    queue =
      :ets.new(:scheduling_queue, [
        :ordered_set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok,
     %{
       receiver: receiver,
       queue: queue,
       name: name,
       index: index
     }}
  end

  def add_ranges(pid, ranges) when is_pid(pid) do
    GenServer.cast(pid, {:add_ranges, ranges})
  end

  def start_scheduling(pid) do
    GenServer.cast(pid, {:start_scheduling})
  end

  def handle_info(:finished, state = %{receiver: receiver, queue: queue}) do
    if ets_count(queue) == 0 do
      send(self(), :stop)
      send(receiver, {:finished, self()})
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(:run, state) do
    schedule_run()
    {:noreply, schedule(state)}
  end

  def handle_cast({:start_scheduling}, state) do
    schedule_run()
    {:noreply, schedule(state)}
  end

  def handle_cast(
        {:add_ranges, ranges},
        state = %{queue: queue, name: name, index: index}
      ) do
    schedule_ranges(name, index, queue, ranges)

    {
      :noreply,
      schedule(state)
    }
  end

  defp schedule_run() do
    Process.send_after(self(), :run, 700)
  end

  defp schedule(
         state = %{
           queue: queue,
           name: name,
           index: index
         }
       ) do
    running()

    count = @concurrent - running()

    case next_ranges(queue, count) do
      {[], _queue, 0} ->
        # IO.puts("waiting for ranges to run #{running}/#{concurrent}")
        nil

      {[], _queue, _} ->
        Process.send_after(self(), :finished, 750)
        state

      {ranges, queue, _} ->
        schedule_ranges(name, index, queue, ranges)

        state
        |> Map.put(:queue, queue)
    end
  end

  def running() do
    Supervisor.count_children(SchedulerSupervisor).active
  end

  def schedule_ranges(name, index, queue, ranges) do
    # to stop sending a notification back from the supervisor
    for range <- ranges do
      Task.Supervisor.start_child(
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
  end

  defp next_ranges(queue, count) when count < 1, do: {[], queue, count}

  defp next_ranges(queue, count) do
    ranges =
      case :ets.select(queue, @query, count) do
        :"$end_of_table" ->
          []

        {ranges, _} ->
          ranges
          |> Enum.map(fn {range} ->
            :ets.delete(queue, range)

            case range do
              {_size, range} -> range
              range -> range
            end
          end)
      end

    {ranges, queue, count}
  end

  defp ets_count(queue) do
    :ets.select_count(queue, @query)
  end
end
