defmodule RodarDemo.Workflow.OrderProcessing.Handlers.SendConfirmation do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"confirmation_sent" => true, "confirmed_at" => DateTime.utc_now() |> to_string()}}
  end
end
