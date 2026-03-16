defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.ProvisionEmail do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, data) do
    employee_name = data["employee_name"] || "employee"
    username = employee_name |> String.downcase() |> String.replace(~r/[^a-z0-9]/, ".")

    {:ok,
     %{
       "email_provisioned" => true,
       "email" => "#{username}@company.com"
     }}
  end
end
