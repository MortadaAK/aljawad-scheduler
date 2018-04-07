defmodule AljawadScheduler.Scheduler do
  @moduledoc """
  Scheduler is responsible of generating the required structure of machines and
  schedule each step in a given job to the master schedule
  """
  alias AljawadScheduler.Permutation

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
