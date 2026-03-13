defmodule RodarDemoWeb.OrderLive.Show do
  use RodarDemoWeb, :live_view

  alias RodarDemo.Workflow.OrderProcessing.Manager
  alias Rodar.Context

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    order_id = String.to_integer(id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, "orders")
    end

    bpmn_xml = load_bpmn_xml()

    case Manager.get_order(order_id) do
      {:ok, order} ->
        {history, data} = fetch_process_info(order)
        {visited, active} = compute_node_state(history, order)

        {:ok,
         assign(socket,
           order: order,
           history: history,
           process_data: data,
           bpmn_xml: bpmn_xml,
           visited_nodes: visited,
           active_nodes: active,
           page_title: "Order ##{order.id}"
         )}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Order not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("approve", _params, socket) do
    case Manager.approve_order(socket.assigns.order.id) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order approved")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  def handle_event("reject", _params, socket) do
    case Manager.reject_order(socket.assigns.order.id) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order rejected")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:order_updated, %{id: id} = _updated_order}, socket) do
    if id == socket.assigns.order.id do
      case Manager.get_order(id) do
        {:ok, order} ->
          {history, data} = fetch_process_info(order)
          {visited, active} = compute_node_state(history, order)

          socket =
            socket
            |> assign(
              order: order,
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

  defp fetch_process_info(%{process_pid: pid} = _order) do
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
    Application.app_dir(:rodar_demo, "priv/bpmn/order_processing.bpmn")
    |> File.read!()
  end

  defp compute_node_state(history, order) do
    all_node_ids =
      history
      |> Enum.map(& &1.node_id)
      |> Enum.reject(&String.starts_with?(&1, "Flow_"))
      |> Enum.uniq()

    case order.status do
      :awaiting_approval ->
        visited = Enum.reject(all_node_ids, &(&1 == "Task_ManagerApproval"))
        {visited, ["Task_ManagerApproval"]}

      _ ->
        {all_node_ids, []}
    end
  end

  defp status_label(:completed), do: "Completed"
  defp status_label(:awaiting_approval), do: "Awaiting Approval"
  defp status_label(:rejected), do: "Rejected"
  defp status_label(:error), do: "Error"
  defp status_label(status), do: status |> to_string() |> String.capitalize()
end
