# defmodule AljawadSchedulerTest do
#   use ExUnit.Case
#   doctest AljawadScheduler

#   test "greets the world" do
#     assert AljawadScheduler.hello() == :world
#   end
# end

defmodule Permutation do
  @moduledoc """
  Calculate and generate all possible combination of ordering elements in a list
  """
  @doc """
  Removes an element from a list by index
  """
  @spec remove_element(List.t(), integer()) :: {List.t(), any()}
  def remove_element([a], 0) do
    {[], a}
  end

  def remove_element([a | rest], 0) do
    {rest, a}
  end

  def remove_element(array, index) do
    {List.delete_at(array, index), Enum.at(array, index)}
  end

  @doc """
  Creates a order combination from a list by passing the array as the first
  argument and the second one as number of the combination.
  """
  @spec create_permutation(List.t()) :: List.t()
  def create_permutation([]), do: []

  @spec create_permutation(List.t(), integer()) :: List.t()
  def create_permutation([], _), do: []

  @spec create_permutation(List.t(), integer()) :: List.t()
  def create_permutation(array, index) do
    multiplier = multiplier(array)
    digit = digit(index, multiplier)
    {new_array, element} = remove_element(array, digit)
    normalize([element] ++ create_permutation(new_array, rem(index, multiplier)))
  end

  @doc """
  returns a number that represent the number of possibilities can be generated by keeping the first element in same index
  """
  @spec multiplier(List.t()) :: integer()
  def multiplier([]), do: 1
  def multiplier([_]), do: 1
  def multiplier(array) when is_list(array), do: factorial(Enum.count(array) - 1)
  def multiplier(range), do: multiplier(Enum.to_list(range))

  @doc """
  Converts a number to an index of the element in the array that should be
  selected
  """
  @spec digit(integer(), integer()) :: integer()
  def digit(int, multiplier), do: div(int, multiplier)

  @doc """
  Generate a factorial of a number
  """
  @spec factorial(integer()) :: integer()
  def factorial(0), do: 1
  def factorial(1), do: 1
  def factorial(number), do: number * factorial(number - 1)

  @doc """
  Remove the first element in the array if it was nil. This happens when the
  index of the permutation passed is grater than the number of possibilities
  where it will cycle again but will start with nils at the beginning.
  """
  def normalize([nil | rest]), do: rest
  def normalize(array), do: array
end

defmodule Scheduler do
  @moduledoc """
  Scheduler is responsible of generating the required structure of machines and
  schedule each step in a given job to the master schedule
  """

  @doc """
  Generate the basic structure of the master schedule by providing list of machines that has a unique key and required hours/minutes to be used in the
  schedule. the generated map will be structured as machine key as the
  identifier and the value is tuple of list of the scheduled operations and
  finish hours/minutes. In this step, the first operation will start with
  `s` to indicate when this machine can start.
  """
  @spec prepare_machines(map()) :: map()
  def prepare_machines(machines) when is_map(machines) do
    machines
    |> Map.keys()
    |> Enum.reduce(%{}, fn key, schedule ->
      value = Map.get(machines, key)
      Map.put(schedule, key, {[{:s, value}], value, 0, 0})
    end)
  end

  @doc """
  schedule a step of a job on the machine by adding a new machine if it was not
  added before. then by checking the earliest time that this operation can start
  against the finish time for the machine.
  1 - if the earliest time for the operation is 0, then the finish time will be
  used as the starting time.
  2- if the earliest time for the operation is equal to the finish time of the
  machine, then will be used as the starting time.
  3- if the finish time of the machine is earlier than the earliest time to
  start the operation, then a `l` lag period with difference between them will
  be added then the period of the operation will be added.
  4- if the finish time of the machine is greater than the earliest starting
  time for the operation, then a `w` waiting period will be added to the
  schedule of the machine.
  The period that will be calculated for each machine, is the sum of the
  starting time for the machine plus all operations period plus any lag between
  them.
  """
  @spec schedule_operation(map(), atom(), atom(), {integer(), integer()}) ::
          {list(), integer(), integer(), integer()}
  def schedule_operation(schedule, machine, job, {start, duration}) do
    {wc_schedule, finish, lag, waiting} = Map.get(schedule, machine, {[s: 0], 0, 0, 0})

    {wc_schedule, finish, lag, waiting} =
      cond do
        finish == start || start == 0 ->
          {
            wc_schedule ++ [{job, duration}],
            duration + finish,
            lag,
            waiting
          }

        finish < start ->
          current_lag = start - finish

          {
            wc_schedule ++ [{:l, current_lag}, {job, duration}],
            duration + finish + current_lag,
            current_lag + lag,
            waiting
          }

        finish > start ->
          current_waiting = finish - start

          {
            wc_schedule ++ [{:w, current_waiting}, {job, duration}],
            duration + finish,
            lag,
            waiting + current_waiting
          }
      end

    {Map.put(schedule, machine, {wc_schedule, finish, lag, waiting}), finish}
  end

  @doc """
  map over a list of operation that belongs to a job and add them to the schedule that was provided.
  """
  @spec schedule_job(map(), atom(), list()) :: map()
  def schedule_job(schedule, job, steps) do
    {new_schedule, _} =
      Enum.reduce(steps, {schedule, 0}, fn {machine, duration}, {new_schedule, start} ->
        schedule_operation(new_schedule, machine, job, {start, duration})
      end)

    new_schedule
  end

  @doc """
  calculate the hours that is required by the list of jobs provided
  and group them by the machine that each step should work on
  """
  @spec max_total_hours(list()) :: map()
  def max_total_hours(jobs) do
    Enum.reduce(jobs, %{}, fn {_, steps}, hours ->
      Enum.reduce(steps, hours, fn {machine, step_hours}, new_hours ->
        {_, new_hours} =
          Map.get_and_update(new_hours, machine, fn current ->
            {current, if(current, do: current + step_hours, else: step_hours)}
          end)

        new_hours
      end)
    end)
  end

  @doc """
  calculate the minimum possible hours that is required by the list of jobs
  provided assuming that there will be no lag between the operations and group
  them by the machine that each step should work on
  """
  @spec min_remaining(map(), list()) :: map()
  def min_remaining(schedule, jobs) do
    timer =
      Enum.reduce(jobs, %{}, fn {_job, schedule}, timer ->
        Enum.reduce(schedule, timer, fn {machine, hours}, timer ->
          {_, new_hours} =
            Map.get_and_update(timer, machine, fn current ->
              {current, if(current, do: current + hours, else: hours)}
            end)

          new_hours
        end)
      end)

    Enum.reduce(schedule, timer, fn {machine, {_, hours, _, _}}, timer ->
      {_, new_timer} =
        Map.get_and_update(timer, machine, fn current ->
          {current, if(current, do: current + hours, else: hours)}
        end)

      new_timer
    end)
  end

  @doc """
  select the maximum required hours between the list that generated by
  `min_remaining/2`
  """
  @spec max_min_remaining(map(), list()) :: integer()
  def max_min_remaining(schedule, jobs) do
    Enum.reduce(min_remaining(schedule, jobs), 0, fn {_machine, hours}, current ->
      max(hours, current)
    end)
  end

  @doc """
  Schedule multiple jobs for a schedule by ordering them based on the permute
  index.
  """
  @spec schedule_jobs(map(), list(), integer()) :: map()
  def schedule_jobs(schedule, jobs, permute \\ 0) do
    jobs
    |> Enum.to_list()
    |> Permutation.create_permutation(permute)
    |> Enum.reduce(schedule, fn {key, steps}, schedule ->
      schedule_job(schedule, key, steps)
    end)
  end

  @doc """
  Get the maximum hours that is required between all work centers.
  """
  @spec get_max(map()) :: integer()
  def get_max(schedule) do
    Enum.reduce(schedule, 0, fn {_key, {_, hours, _, _}}, current_hours ->
      max(hours, current_hours)
    end)
  end

  @doc """
  Sum all waiting hours
  """
  @spec get_waiting(map()) :: integer()
  def get_waiting(schedule) do
    Enum.reduce(schedule, 0, fn {_key, {_, _, _, hours}}, current_hours ->
      hours + current_hours
    end)
  end

  @doc """
  Sum all lag hours
  """
  @spec get_lags(map()) :: integer()
  def get_lags(schedule) do
    Enum.reduce(schedule, 0, fn {_key, {_, _, hours, _}}, current_hours ->
      hours + current_hours
    end)
  end

  defp sum_by_type(schedule, type) do
    Enum.reduce(schedule, 0, fn {_machine, {jobs, _total_hours}}, hours ->
      Enum.reduce(jobs, hours, fn {step, h}, hours ->
        case step do
          ^type -> hours + h
          _ -> hours
        end
      end)
    end)
  end
end

defmodule ScheduleRunner do
  @moduledoc """
  A server that will handle the operations to prepare and generate the most
  optimize schedule.
  """
  use GenServer

  # Client

  def start_link(default) do
    GenServer.start_link(__MODULE__, default)
  end

  @doc """
  returns the list of machines that is used in the schedule.
  """
  @spec machines(pid()) :: {:ok, map()}
  def machines(pid) do
    GenServer.call(pid, :machines)
  end

  @doc """
  returns the name of the ets table that is going to be used to store the
  maximum number of hours that which the scheduling should stop at
  """
  @spec name(pid()) :: {:ok, atom()}
  def name(pid) do
    GenServer.call(pid, :name)
  end

  @doc """
  returns the list of jobs that is going to be scheduled.
  """
  @spec jobs(pid) :: {:ok, list()}
  def jobs(pid) do
    GenServer.call(pid, :jobs)
  end

  @doc """
  returns the maximum number of hours that which the scheduling should stop at
  """
  @spec max(pid) :: {:ok, integer()}
  def max(pid) do
    GenServer.call(pid, :max, :infinity)
  end

  @doc """
  The selected most optimized schedule found yet
  """
  @spec current_schedule(pid) :: {:ok, map()}
  def current_schedule(pid) do
    GenServer.call(pid, :current_schedule, :infinity)
  end

  @doc """
  propose a schedule to be the optimized one
  """
  def set_schedule(pid, schedule) do
    GenServer.cast(pid, {:current_schedule, schedule})
  end

  @doc """
  Starts the searching process for the optimized schedule. the process will do:
  1- build multiple schedules by mapping over jobs and allowing them to be the
  first job to run. then select the most optimized one the be the base line for
  the search.
  2- Go over all jobs and create a process that will search for an optimized
  schedule that start with the selected job as the first one to run.
  """
  def start_scheduling(pid) do
    {:ok, jobs} = ScheduleRunner.jobs(pid)
    {:ok, machines} = ScheduleRunner.machines(pid)
    {:ok, name} = ScheduleRunner.name(pid)

    jobs = Map.to_list(jobs)

    count =
      for job <- jobs do
        Task.async(fn ->
          rest_of_jobs = List.delete(jobs, job)
          ScheduleRunner.schedule(pid, name, machines, job, rest_of_jobs, 0)
        end)
      end
      |> Enum.map(&Task.await(&1, :infinity))
      |> Enum.sum()

    IO.inspect("Total Skipped #{count}")

    current_schedule(pid)
  end

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
        Task.async(fn ->
          for next <- remaining_jobs do
            rest_of_jobs = List.delete(remaining_jobs, next)
            ScheduleRunner.schedule(pid, name, new_schedule, next, rest_of_jobs, level + 1)
          end
        end)
        |> (&[&1]).()
      else
        for next <- remaining_jobs do
          Task.async(fn ->
            rest_of_jobs = List.delete(remaining_jobs, next)

            ScheduleRunner.schedule(pid, name, new_schedule, next, rest_of_jobs, level + 1)
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

  # Server (callbacks)

  def init(%{machines: machines, jobs: jobs, name: name}) do
    machines = Scheduler.prepare_machines(machines)
    :ets.new(name, [:named_table, :set, :protected, read_concurrency: true])
    :ets.insert(name, {"max", 100_000_000})
    :ets.insert(name, {"lags", 100_000_000})
    :ets.insert(name, {"waiting", 100_000_000})

    size = Permutation.factorial(Enum.count(jobs) - 1)

    selected =
      Enum.reduce(1..(Enum.count(jobs) - 1), nil, fn i, selected ->
        new_schedule = Scheduler.schedule_jobs(machines, jobs, i * size)

        case check_schedule(new_schedule, name) do
          {:ok, schedule, _new_max, _new_lags, _new_waiting} ->
            schedule

          _ ->
            selected
        end
      end)

    {:ok,
     %{
       machines: machines,
       jobs: jobs,
       current_schedule: selected,
       name: name
     }}
  end

  def handle_call(:jobs, _from, t) do
    {:reply, {:ok, t.jobs}, t}
  end

  def handle_call(:name, _from, t) do
    {:reply, {:ok, t.name}, t}
  end

  def handle_call(:max, _from, t) do
    max =
      case :ets.lookup(t.name, "max") do
        [{"max", max}] -> max
        _ -> 1_000_000
      end

    {:reply, {:ok, max}, t}
  end

  def handle_call(:machines, _from, t) do
    {:reply, {:ok, t.machines}, t}
  end

  def handle_call(:current_schedule, _from, t) do
    {:reply, {:ok, t.current_schedule}, t}
  end

  def handle_cast(
        {:current_schedule, next_schedule},
        state = %{name: name}
      ) do
    ## TODO: add optimization for waiting and lagging time

    case check_schedule(next_schedule, name) do
      {:ok, schedule, max, lag, waiting} ->
        :ets.insert(name, {"max", max})
        :ets.insert(name, {"lags", lag})
        :ets.insert(name, {"waiting", waiting})

        IO.inspect(
          "Did change schedule period to #{max}, lag to #{lag} and waiting to #{waiting}"
        )

        {
          :noreply,
          state
          |> Map.put(:max, max)
          |> Map.put(:lag, lag)
          |> Map.put(:waiting, waiting)
          |> Map.put(:current_schedule, schedule)
        }

      {:no_change} ->
        {:noreply, state}
    end
  end

  defp check_schedule(schedule, name) do
    new_max = Scheduler.get_max(schedule)
    new_lags = Scheduler.get_lags(schedule)
    new_waiting = Scheduler.get_waiting(schedule)

    [{"max", current_max}] = :ets.lookup(name, "max")
    [{"lags", current_lags}] = :ets.lookup(name, "lags")
    [{"waiting", current_waiting}] = :ets.lookup(name, "waiting")

    max_reduced = new_max < current_max
    max_not_changed = new_max == current_max
    lags_reduced = new_lags <= current_lags
    waiting_reduced = new_waiting <= current_waiting

    if max_reduced || (max_not_changed && lags_reduced && waiting_reduced) do
      :ets.insert(name, {"max", new_max})
      :ets.insert(name, {"lags", new_lags})
      :ets.insert(name, {"waiting", new_waiting})

      {:ok, schedule, new_max, new_lags, new_waiting}
    else
      {:no_change}
    end
  end
end

defmodule SchedulerTest do
  use ExUnit.Case

  test "prepare machine schedule" do
    assert %{m1: {[s: 10], 10, 0, 0}} =
             %{m1: 10}
             |> Scheduler.prepare_machines()
  end

  test "add a job to a machine" do
    assert {%{m1: {[s: 10, j1: 5], 15, 0, 0}}, 15} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {0, 5})
  end

  test "minimum possible remaining hours" do
    schedule = %{
      m1: {[s: 10], 10, 0, 0},
      m2: {[s: 5], 5, 0, 0},
      m3: {[s: 0], 0, 0, 0},
      m4: {[s: 15], 15, 0, 0},
      m5: {[s: 2], 2, 0, 0}
    }

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 2],
      j2: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
    }

    assert %{m1: 14, m2: 9, m3: 2, m4: 21, m5: 17} = Scheduler.min_remaining(schedule, jobs)
  end

  test "maximum minimum possible remaining hours" do
    schedule = %{
      m1: {[s: 10], 10, 0, 0},
      m2: {[s: 5], 5, 0, 0},
      m3: {[s: 0], 0, 0, 0},
      m4: {[s: 15], 15, 0, 0},
      m5: {[s: 2], 2, 0, 0}
    }

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 2],
      j2: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
    }

    assert 21 = Scheduler.max_min_remaining(schedule, jobs)
  end

  test "max of sum of total hours per machine" do
    assert %{m1: 4, m2: 4, m3: 2, m4: 6, m5: 15} =
             Scheduler.max_total_hours(%{
               j1: [m1: 2, m2: 2, m4: 2],
               j4: [m1: 2, m2: 2, m3: 2, m4: 4, m5: 15]
             })
  end

  test "add a job to a machine with a lag" do
    assert {%{
              m1: {[s: 10, l: 5, j1: 5], 20, 5, 0}
            },
            20} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {15, 5})
  end

  test "add a job to a machine with a waiting" do
    assert {%{
              m1: {[s: 10, w: 5, j1: 5], 15, 0, 5}
            },
            15} =
             %{m1: {[s: 10], 10, 0, 0}}
             |> Scheduler.schedule_operation(:m1, :j1, {5, 5})
  end

  describe "schedule" do
    setup do
      machines = %{m1: 10, m2: 5, m3: 0, m4: 15}

      jobs = %{
        j1: [m1: 2, m2: 2, m4: 6],
        j2: [m1: 3, m3: 6, m4: 2],
        j3: [m2: 2, m3: 4, m4: 1],
        j4: [m1: 2, m2: 2, m3: 1, m4: 1]
      }

      {:ok, jobs: jobs, machines: machines}
    end

    test "add a job to a schedule", %{jobs: %{j1: job}, machines: machines} do
      assert %{
               m1: {[s: 10, j1: 2], 12, 0, 0},
               m2: {[s: 5, l: 7, j1: 2], 14, 7, 0},
               m3: {[s: 0], 0, 0, 0},
               m4: {[s: 15, w: 1, j1: 6], 21, 0, 1}
             } =
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_job(:j1, job)
    end

    test "add multiple jobs to a schedule", %{jobs: jobs, machines: machines} do
      wanted = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert wanted ==
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_jobs(jobs)
    end

    test "add multiple jobs to a schedule bay passing the permute number", %{
      jobs: jobs,
      machines: machines
    } do
      wanted = %{
        m1: {[s: 10, j4: 2, j2: 3, j1: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j4: 2, j3: 2, l: 1, j1: 2], 19, 8, 0},
        m3: {[s: 0, l: 14, j4: 1, l: 1, j3: 4, w: 5, j2: 6], 26, 15, 5},
        m4: {[s: 15, j4: 1, l: 4, j3: 1, l: 5, j2: 2, w: 9, j1: 6], 34, 9, 9}
      }

      assert wanted ==
               machines
               |> Scheduler.prepare_machines()
               |> Scheduler.schedule_jobs(jobs, 23)
    end

    test "calculate sim of lag hours" do
      schedule = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert 25 = Scheduler.get_lags(schedule)
    end

    test "calculate sim of waiting hours" do
      schedule = %{
        m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
        m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
        m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
        m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
      }

      assert 12 = Scheduler.get_waiting(schedule)
    end
  end
end

defmodule PermutationTest do
  use ExUnit.Case

  describe "remove element" do
    test "remove first element from array with one element" do
      assert {[], 1} = Permutation.remove_element([1], 0)
    end

    test "remove first element from array" do
      assert {[2, 3], 1} = Permutation.remove_element([1, 2, 3], 0)
    end

    test "remove element in the middle" do
      assert {[1, 3], 2} = Permutation.remove_element([1, 2, 3], 1)
    end

    test "remove last element" do
      assert {[1, 2], 3} = Permutation.remove_element([1, 2, 3], 2)
    end
  end

  describe "factorial" do
    test "factorial 0" do
      assert 1 = Permutation.factorial(0)
    end

    test "factorial 1" do
      assert 1 = Permutation.factorial(1)
    end

    test "factorial 2" do
      assert 2 = Permutation.factorial(2)
    end

    test "factorial 3" do
      assert 6 = Permutation.factorial(3)
    end

    test "factorial 4" do
      assert 24 = Permutation.factorial(4)
    end

    test "factorial 5" do
      assert 120 = Permutation.factorial(5)
    end
  end

  describe "multiplier" do
    test "multiplier 0" do
      assert 1 = Permutation.multiplier([])
    end

    test "multiplier 1" do
      assert 1 = Permutation.multiplier([1])
    end

    test "multiplier 2" do
      assert 1 = Permutation.multiplier(1..2)
    end

    test "multiplier 3" do
      assert 2 = Permutation.multiplier(1..3)
    end

    test "multiplier 4" do
      assert 6 = Permutation.multiplier(1..4)
    end

    test "multiplier 5" do
      assert 24 = Permutation.multiplier(1..5)
    end
  end

  describe "digit" do
    test "digit" do
      assert 0 = Permutation.digit(1, 3)
      assert 1 = Permutation.digit(4, 3)
    end
  end

  describe "create permutation" do
    setup do
      {:ok, array: ["a", "b", "c"]}
    end

    test "return empty array for empty args" do
      assert [] = Permutation.create_permutation([])
      assert [] = Permutation.create_permutation([], 0)
    end

    test "first permute for an array", %{array: array} do
      assert ["a", "b", "c"] = Permutation.create_permutation(array, 0)
    end

    test "second permute for an array", %{array: array} do
      assert ["a", "c", "b"] = Permutation.create_permutation(array, 1)
    end

    test "third permute for an array", %{array: array} do
      assert ["b", "a", "c"] = Permutation.create_permutation(array, 2)
    end

    test "4th permute for an array", %{array: array} do
      assert ["b", "c", "a"] = Permutation.create_permutation(array, 3)
    end

    test "5th permute for an array", %{array: array} do
      assert ["c", "a", "b"] = Permutation.create_permutation(array, 4)
    end

    test "6th permute for an array", %{array: array} do
      assert ["c", "b", "a"] = Permutation.create_permutation(array, 5)
    end

    # @tag timeout: 25_000_000
    # test "generate batches", %{array: array} do
    #   target = 1

    #   limit = Permutation.factorial(target)
    #   portion = 10_000

    #   group_size =
    #     (limit / portion)
    #     |> round
    #     |> IO.inspect()

    #   for s <- 0..group_size do
    #     start_at = s * portion
    #     end_at = min((s + 1) * portion - 1, limit)
    #     IO.inspect("#{start_at}..#{end_at} Started")

    #     Task.async(fn ->
    #       {t, nil} =
    #         :timer.tc(fn ->
    #           for i <- start_at..end_at do
    #             1..target
    #             |> Enum.to_list()
    #             |> Permutation.create_permutation(i)

    #             nil
    #           end

    #           nil
    #         end)

    #       IO.inspect("#{start_at}..#{end_at} Ended #{t / 1_000_000}")
    #     end)
    #   end
    #   |> Enum.map(&Task.await(&1, :infinity))
    # end
  end
end

defmodule ScheduleRunnerTest do
  use ExUnit.Case

  setup do
    machines = %{m1: 10, m2: 5, m3: 0, m4: 15}

    jobs = %{
      j1: [m1: 2, m2: 2, m4: 6],
      j2: [m1: 3, m3: 6, m4: 2],
      j3: [m2: 2, m3: 4, m4: 1],
      j4: [m1: 2, m2: 2, m3: 1, m4: 1]
    }

    {:ok, jobs: jobs, machines: machines, name: :scheduler1233}
  end

  test "initialize with machines", args do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok,
            %{
              m1: {[s: 10], 10, 0, 0},
              m2: {[s: 5], 5, 0, 0},
              m3: {[s: 0], 0, 0, 0},
              m4: {[s: 15], 15, 0, 0}
            }} = ScheduleRunner.machines(pid)
  end

  test "initialize with jobs", args = %{jobs: jobs} do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok, ^jobs} = ScheduleRunner.jobs(pid)
  end

  test "initialize with first schedule", args = %{jobs: _jobs} do
    assert {:ok, pid} = ScheduleRunner.start_link(args)

    assert {:ok, 27} = ScheduleRunner.max(pid)

    assert {:ok,
            %{
              m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
              m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
              m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
              m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
            }} = ScheduleRunner.current_schedule(pid)
  end

  test "set schedule", args do
    new_schedule = %{
      m1: {[s: 10, j1: 2, j2: 3, j4: 2], 17, 0, 0},
      m2: {[s: 5, l: 7, j1: 2, j3: 2, l: 1, j4: 2], 19, 8, 0},
      m3: {[s: 0, l: 15, j2: 6, w: 5, j3: 4, w: 6, j4: 1], 26, 15, 11},
      m4: {[s: 15, w: 1, j1: 6, j2: 2, l: 2, j3: 1, j4: 1], 27, 2, 1}
    }

    assert {:ok, pid} = ScheduleRunner.start_link(args)
    assert :ok = ScheduleRunner.set_schedule(pid, new_schedule)
    assert {:ok, ^new_schedule} = ScheduleRunner.current_schedule(pid)
  end

  @tag timeout: 5_000_000
  test "schedule all" do
    start = fn ->
      IO.inspect(DateTime.utc_now())

      machines = %{m1: 10, m2: 5, m3: 0, m4: 15, m5: 5, m6: 2, m7: 20, m8: 0, m9: 10}

      jobs = %{
        j1: [m1: 2, m2: 2, m4: 6],
        j2: [m1: 3, m3: 6, m4: 2],
        j3: [m2: 2, m3: 4, m4: 1],
        j4: [m1: 2, m2: 2, m3: 1, m4: 1],
        j5: [m1: 4, m6: 12, m3: 16, m7: 6],
        j6: [m3: 6, m4: 12, m5: 16, m7: 6],
        j7: [m2: 3, m5: 5, m9: 6],
        j8: [m1: 6, m2: 12, m3: 6, m4: 6, m5: 8, m6: 4, m7: 10],
        j9: [m1: 6, m2: 12, m5: 8, m6: 4, m8: 10],
        j10: [m1: 6, m4: 12, m3: 8, m6: 4, m7: 10],
        j11: [m1: 10, m2: 12, m3: 8, m9: 4, m7: 10],
        j12: [m2: 10, m1: 12, m3: 18, m6: 5, m9: 10],
        j13: [m3: 10, m2: 1, m4: 8, m6: 5, m7: 10],
        j14: [m1: 3, m2: 3, m8: 3, m3: 5, m9: 10],
        j15: [m1: 3, m1: 3, m2: 3, m4: 5, m6: 10],
        j16: [m1: 3, m5: 3]
        # j17: [m1: 3, m6: 9, m9: 4],
        # j18: [m1: 10, m6: 8, m9: 7],
        # j19: [m2: 6, m4: 8, m5: 9, m7: 6],
        # j20: [m1: 6, m3: 8, m5: 9, m7: 6],
        # j21: [m2: 6, m4: 8, m6: 9, m8: 6],
        # j22: [m3: 3, m4: 5, m6: 5, m8: 12],
        # j23: [m4: 10, m5: 12, m3: 8, m9: 4, m7: 10],
        # j24: [m1: 2, m5: 3, m3: 8, m9: 4, m7: 10],
        # j25: [m1: 2, m4: 3, m3: 8, m8: 4, m9: 10]
      }

      # :observer.start()

      {:ok, pid} =
        ScheduleRunner.start_link(%{machines: machines, jobs: jobs, name: :schedule123})

      :timer.tc(fn -> ScheduleRunner.start_scheduling(pid) end) |> IO.inspect()

      IO.inspect(DateTime.utc_now())
    end

    start.()
  end
end
