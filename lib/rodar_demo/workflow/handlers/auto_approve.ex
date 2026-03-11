defmodule RodarDemo.Workflow.Handlers.AutoApprove do
  @behaviour RodarBpmn.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, _data) do
    {:ok, %{"approved" => true, "approval_type" => "auto"}}
  end
end
