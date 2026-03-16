defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.CreateTrainingPlan do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    plan_id =
      "TP-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"

    {:ok, %{"training_plan_id" => plan_id}}
  end
end
