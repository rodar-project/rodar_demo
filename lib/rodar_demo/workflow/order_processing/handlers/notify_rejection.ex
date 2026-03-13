defmodule RodarDemo.Workflow.OrderProcessing.Handlers.NotifyRejection do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"rejected" => true, "rejected_at" => DateTime.utc_now() |> to_string()}}
  end
end
