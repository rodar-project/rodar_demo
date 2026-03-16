defmodule RodarDemo.Workflow.EmployeeOnboarding.Handlers.SendWelcomePackage do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok,
     %{
       "welcome_sent" => true,
       "welcome_sent_at" => DateTime.utc_now() |> to_string()
     }}
  end
end
