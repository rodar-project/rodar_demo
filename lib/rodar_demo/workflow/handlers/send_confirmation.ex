defmodule RodarDemo.Workflow.Handlers.SendConfirmation do
  @behaviour RodarBpmn.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"confirmation_sent" => true, "confirmed_at" => DateTime.utc_now() |> to_string()}}
  end
end
