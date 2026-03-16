defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.SetupCRMAccess do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"crm_access" => true}}
  end
end
