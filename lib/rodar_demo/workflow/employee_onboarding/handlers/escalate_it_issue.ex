defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.EscalateITIssue do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    ticket_id =
      "IT-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"

    {:ok, %{"escalated" => true, "ticket_id" => ticket_id}}
  end
end
