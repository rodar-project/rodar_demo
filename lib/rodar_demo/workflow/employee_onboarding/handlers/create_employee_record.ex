defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.CreateEmployeeRecord do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, data) do
    employee_id =
      "EMP-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"

    {:ok,
     %{
       "employee_id" => employee_id,
       "record_created" => true,
       "record_created_at" => DateTime.utc_now() |> to_string(),
       "employee_name" => data["employee_name"],
       "role" => data["role"],
       "department" => data["department"]
     }}
  end
end
