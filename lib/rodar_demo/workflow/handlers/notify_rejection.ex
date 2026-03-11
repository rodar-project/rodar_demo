defmodule RodarDemo.Workflow.Handlers.NotifyRejection do
  @behaviour RodarBpmn.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"rejected" => true, "rejected_at" => DateTime.utc_now() |> to_string()}}
  end
end
