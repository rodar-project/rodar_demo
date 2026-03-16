defmodule RodarDemoWeb.OnboardingLive.Index do
  use RodarDemoWeb, :live_view

  alias RodarDemo.Workflow.EmployeeOnboarding.Manager

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, "onboardings")
    end

    onboardings = Manager.list_onboardings()
    {:ok, assign(socket, onboardings: onboardings, page_title: "Onboardings")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Onboarding")
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Onboardings")
  end

  @impl true
  def handle_event("start_onboarding", %{"onboarding" => params}, socket) do
    case Manager.start_onboarding(params) do
      {:ok, _onboarding} ->
        {:noreply,
         socket
         |> put_flash(:info, "Onboarding started successfully")
         |> push_navigate(to: ~p"/onboarding")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start onboarding: #{inspect(reason)}")}
    end
  end

  def handle_event("assign_mentor", %{"id" => id, "mentor" => mentor}, socket) do
    onboarding_id = String.to_integer(id)

    case Manager.assign_mentor(onboarding_id, mentor) do
      {:ok, _onboarding} ->
        {:noreply, put_flash(socket, :info, "Mentor assigned")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to assign mentor: #{inspect(reason)}")}
    end
  end

  def handle_event("complete_checkin", %{"id" => id}, socket) do
    onboarding_id = String.to_integer(id)

    case Manager.complete_checkin(onboarding_id) do
      {:ok, _onboarding} ->
        {:noreply, put_flash(socket, :info, "Check-in completed")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to complete check-in: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:onboarding_updated, _onboarding}, socket) do
    if socket.assigns[:refresh_timer] do
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    timer = Process.send_after(self(), :refresh_onboardings, 200)
    {:noreply, assign(socket, refresh_timer: timer)}
  end

  def handle_info(:refresh_onboardings, socket) do
    onboardings = Manager.list_onboardings()
    {:noreply, assign(socket, onboardings: onboardings, refresh_timer: nil)}
  end

  defp status_label(:completed), do: "Completed"
  defp status_label(:awaiting_mentor_assignment), do: "Awaiting Mentor Assignment"
  defp status_label(:awaiting_checkin), do: "Awaiting Check-in"
  defp status_label(:awaiting_action), do: "Awaiting Action"
  defp status_label(:error), do: "Error"
  defp status_label(status), do: status |> to_string() |> String.capitalize()
end
