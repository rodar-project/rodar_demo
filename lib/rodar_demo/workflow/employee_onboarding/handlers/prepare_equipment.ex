defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.PrepareEquipment do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    equipment_id =
      "EQ-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"

    {:ok, %{"equipment_ready" => true, "equipment_id" => equipment_id}}
  end
end
