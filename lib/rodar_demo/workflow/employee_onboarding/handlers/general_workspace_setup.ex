defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.GeneralWorkspaceSetup do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"workspace_ready" => true}}
  end
end
