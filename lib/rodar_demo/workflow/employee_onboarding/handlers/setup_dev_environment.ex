defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.SetupDevEnvironment do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"dev_env_ready" => true}}
  end
end
