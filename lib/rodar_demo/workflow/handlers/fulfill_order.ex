defmodule RodarDemo.Workflow.Handlers.FulfillOrder do
  @behaviour RodarBpmn.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    fulfillment_id = "FUL-#{:rand.uniform(99999) |> Integer.to_string() |> String.pad_leading(5, "0")}"
    {:ok, %{"fulfilled" => true, "fulfillment_id" => fulfillment_id}}
  end
end
