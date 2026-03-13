defmodule RodarDemo.Workflow.EmployeeOnboarding.Manager do
  use Rodar.Workflow.Server,
    bpmn_file: "priv/bpmn/employee_onboarding.bpmn",
    process_id: "employee_onboarding",
    otp_app: :rodar_demo,
    app_name: "RodarDemo"

  alias Rodar.Context

  # --- Workflow Callbacks ---

  @impl Rodar.Workflow.Server
  def init_data(params, instance_id) do
    %{
      "employee_name" => to_string(params["employee_name"] || params[:employee_name] || ""),
      "role" => to_string(params["role"] || params[:role] || "other"),
      "department" => to_string(params["department"] || params[:department] || ""),
      "start_date" => to_string(params["start_date"] || params[:start_date] || ""),
      "manager_name" => to_string(params["manager_name"] || params[:manager_name] || ""),
      "onboarding_id" => instance_id
    }
  end

  @impl Rodar.Workflow.Server
  def map_status(:suspended), do: :awaiting_action
  def map_status(other), do: other

  # --- Domain API ---

  def start_onboarding(params) do
    case create_instance(params) do
      {:ok, instance} ->
        onboarding = enrich_instance(instance)
        broadcast_update(onboarding)
        {:ok, onboarding}

      error ->
        error
    end
  end

  def assign_mentor(onboarding_id, mentor_name) do
    case complete_task(onboarding_id, "Task_AssignMentor", %{
           "mentor_name" => mentor_name,
           "mentor_assigned" => true
         }) do
      {:ok, instance} ->
        onboarding = enrich_instance(instance)
        broadcast_update(onboarding)
        {:ok, onboarding}

      error ->
        error
    end
  end

  def complete_checkin(onboarding_id) do
    case complete_task(onboarding_id, "Task_FirstWeekCheckin", %{
           "checkin_completed" => true,
           "checkin_completed_at" => DateTime.utc_now() |> to_string()
         }) do
      {:ok, instance} ->
        onboarding = enrich_instance(instance)
        broadcast_update(onboarding)
        {:ok, onboarding}

      error ->
        error
    end
  end

  def list_onboardings do
    list_instances() |> Enum.map(&enrich_instance/1)
  end

  def get_onboarding(id) do
    case get_instance(id) do
      {:ok, instance} -> {:ok, enrich_instance(instance)}
      error -> error
    end
  end

  # --- Private Helpers ---

  defp enrich_instance(instance) do
    data = process_data(instance.process_pid)

    active_task =
      if Process.alive?(instance.process_pid) do
        context = Rodar.Process.get_context(instance.process_pid)
        history = Context.get_history(context)

        history
        |> Enum.filter(&(&1.result == :manual))
        |> Enum.map(& &1.node_id)
        |> List.last()
      end

    mapped_status =
      case {instance.status, active_task} do
        {:awaiting_action, "Task_AssignMentor"} -> :awaiting_mentor_assignment
        {:awaiting_action, "Task_FirstWeekCheckin"} -> :awaiting_checkin
        {status, _} -> status
      end

    Map.merge(instance, %{
      employee_name: data["employee_name"] || "",
      role: data["role"] || "",
      department: data["department"] || "",
      status: mapped_status,
      active_task: active_task
    })
  rescue
    _ -> instance
  end

  defp broadcast_update(onboarding) do
    Phoenix.PubSub.broadcast(RodarDemo.PubSub, "onboardings", {:onboarding_updated, onboarding})
  end
end
