defmodule AljawadScheduler.SchedulerServer do
  use GenServer

  alias AljawadScheduler.{
    Scheduler,
    Permutation,
    ScheduleRunner,
    SchedulerWorker,
    SchedulerServer,
    SchedulerWorkerSupervisor
  }

  @concurrent_processes 50_000
  # Client

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  def init({name, index, schedule, next_job, rest_of_jobs, level}) do
    # Schedule work to be performed on start
    start_schedule()
    counter = :ets.new(:counter, [])
    data = :ets.new(:data, [])
    :ets.insert(counter, {"count", 0})
    :ets.insert(counter, {"working", 0})
    :ets.insert(counter, {"waiting", 0})
    insert(counter, data, {name, index, schedule, next_job, rest_of_jobs, level})

    {:ok,
     %{
       counter: counter,
       data: data,
       receivers: [],
       limit: Enum.count(rest_of_jobs) + 1
     }}
  end

  def push(pid, schedules) do
    GenServer.cast(pid, {:push, schedules})
  end

  def remove(pid, schedule) do
    GenServer.cast(pid, {:remove, schedule})
  end

  def register(pid) do
    GenServer.cast(pid, {:register, self()})
  end

  # Server (callbacks)
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

  defp increment(counter, type, by) do
    :ets.update_counter(counter, type, by)
  end

  def handle_info(:schedule, state) do
    # Do the desired work here
    # Reschedule once more
    start_schedule()
    # IO.puts("called from interval")
    {:noreply, start_scheduling(state)}
  end

  def handle_cast({:register, from}, state) do
    {_, new_state} =
      Map.get_and_update(state, :receivers, fn receivers ->
        case receivers do
          nil -> {receivers, [from]}
          receivers -> {receivers, [from | receivers]}
        end
      end)

    {:noreply, start_scheduling(new_state)}
  end

  def handle_cast(
        {:remove, {index, schedule}},
        status = %{
          counter: counter,
          data: data
        }
      ) do
    remove(counter, data, {index, schedule})

    {:noreply, start_scheduling(status)}
  end

  def handle_cast({:push, []}, state) do
    {:noreply, state}
  end

  def handle_cast({:push, schedules}, status = %{data: data, counter: counter}) do
    Enum.map(schedules, fn s -> insert(counter, data, s) end)

    {:noreply, start_scheduling(status)}
  end

  defp start_schedule() do
    # In 2 seconds
    Process.send_after(self(), :schedule, 2000)
  end

  defp start_scheduling(
         state = %{limit: limit, data: data, counter: counter, receivers: receivers}
       ) do
    cond do
      should_schedule?(state) ->
        for i <- 0..limit do
          query = [
            {
              {:_, {:_, :_, :_, :_, :_, :"$2"}, :"$1"},
              [
                {:andalso, {:==, :"$1", "waiting"}, {:==, :"$2", i}}
              ],
              [:"$_"]
            }
          ]

          group =
            case :ets.select(data, query, @concurrent_processes) do
              {match, _} -> match
              :"$end_of_table" -> []
            end

          run_schedules(group, data, counter)
        end

      any_remaining?(state) ->
        # IO.puts("cannot schedule anything #{Enum.count(state.working)}/#{@concurrent_processes}")
        # IO.inspect(state)
        nil

      true ->
        Enum.each(receivers, fn pid -> Process.send(pid, :finish, []) end)
    end

    state
  end

  defp run_schedules(list, data, counter) do
    pid = self()

    list
    |> Enum.map(&schedule(pid, data, counter, &1))
  end

  defp schedule(
         pid,
         data,
         counter,
         {ets_index, {name, index, schedule, next_job, remaining_jobs, level}, "waiting"}
       ) do
    increment(counter, "working", 1)
    :ets.update_element(data, ets_index, {3, "working"})

    Task.Supervisor.start_child(SchedulerWorkerSupervisor, fn ->
      schedules = SchedulerWorker.schedule(name, index, schedule, next_job, remaining_jobs, level)

      SchedulerServer.remove(
        pid,
        {ets_index, {name, index, schedule, next_job, remaining_jobs, level}}
      )

      SchedulerServer.push(pid, schedules)
    end)
  end

  defp should_schedule?(%{counter: counter, limit: limit}) do
    working = count(counter, "working")
    working <= @concurrent_processes * limit
    working <= 0
  end

  defp any_remaining?(%{counter: counter}) do
    count(counter, "working") + count(counter, "waiting") > 0
  end
end
