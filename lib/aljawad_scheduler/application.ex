defmodule AljawadScheduler.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # supervisor(Task.Supervisor, [[name: AljawadScheduler.SchedulerWorkerSupervisor]])

      # Starts a worker by calling: AljawadScheduler.Worker.start_link(arg)
      # {AljawadScheduler.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AljawadScheduler.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
