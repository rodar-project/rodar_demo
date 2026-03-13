defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.SetupVPN do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"vpn_configured" => true}}
  end
end
