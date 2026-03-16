defmodule RodarDemoWeb.OnboardingLive.Show do
  use RodarDemoWeb, :live_view

  alias RodarDemo.Workflow.EmployeeOnboarding.Manager
  alias Rodar.Context

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    onboarding_id = String.to_integer(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, "onboardings")
    end

    bpmn_xml = load_bpmn_xml()

    case Manager.get_onboarding(onboarding_id) do
      {:ok, onboarding} ->
        {history, data} = fetch_process_info(onboarding)
        {visited, active} = compute_node_state(history, onboarding)

        {:ok,
         assign(socket,
           onboarding: onboarding,
           history: history,
           process_data: data,
           bpmn_xml: bpmn_xml,
           visited_nodes: visited,
           active_nodes: active,
           page_title: "Onboarding ##{onboarding.id}"
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Onboarding not found")
         |> push_navigate(to: ~p"/onboarding")}
    end
  end

  @impl true
  def handle_event("assign_mentor", %{"mentor" => mentor}, socket) do
    case Manager.assign_mentor(socket.assigns.onboarding.id, mentor) do
      {:ok, _onboarding} ->
        {:noreply, put_flash(socket, :info, "Mentor assigned")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  def handle_event("complete_checkin", _params, socket) do
    case Manager.complete_checkin(socket.assigns.onboarding.id) do
      {:ok, _onboarding} ->
        {:noreply, put_flash(socket, :info, "Check-in completed")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:onboarding_updated, %{id: id}}, socket) do
    if id == socket.assigns.onboarding.id do
      case Manager.get_onboarding(id) do
        {:ok, onboarding} ->
          {history, data} = fetch_process_info(onboarding)
          {visited, active} = compute_node_state(history, onboarding)

          socket =
            socket
            |> assign(
              onboarding: onboarding,
              history: history,
              process_data: data,
              visited_nodes: visited,
              active_nodes: active
            )
            |> push_event("bpmn:update_state", %{visited: visited, active: active})

          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp fetch_process_info(%{process_pid: pid}) do
    if Process.alive?(pid) do
      context = Rodar.Process.get_context(pid)
      history = Context.get_history(context)
      data = Context.get(context, :data)
      {history, data}
    else
      {[], %{}}
    end
  rescue
    _ -> {[], %{}}
  end

  defp load_bpmn_xml do
    Application.app_dir(:rodar_demo, "priv/bpmn/employee_onboarding.bpmn")
    |> File.read!()
  end

  defp compute_node_state(history, onboarding) do
    all_node_ids =
      history
      |> Enum.map(& &1.node_id)
      |> Enum.reject(&String.starts_with?(&1, "Flow_"))
      |> Enum.reject(&String.starts_with?(&1, "SF_"))
      |> Enum.uniq()

    case onboarding.status do
      :awaiting_mentor_assignment ->
        visited = Enum.reject(all_node_ids, &(&1 == "Task_AssignMentor"))
        {visited, ["Task_AssignMentor"]}

      :awaiting_checkin ->
        visited = Enum.reject(all_node_ids, &(&1 == "Task_FirstWeekCheckin"))
        {visited, ["Task_FirstWeekCheckin"]}

      _ ->
        {all_node_ids, []}
    end
  end

  defp status_label(:completed), do: "Completed"
  defp status_label(:awaiting_mentor_assignment), do: "Awaiting Mentor Assignment"
  defp status_label(:awaiting_checkin), do: "Awaiting Check-in"
  defp status_label(:awaiting_action), do: "Awaiting Action"
  defp status_label(:error), do: "Error"
  defp status_label(status), do: status |> to_string() |> String.capitalize()
end
