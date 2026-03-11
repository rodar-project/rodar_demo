defmodule RodarDemoWeb.OrderLive.Index do
  use RodarDemoWeb, :live_view

  alias RodarDemo.Workflow.Manager

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, "orders")
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, "bulk_simulation")
    end

    orders = Manager.list_orders()
    {:ok, assign(socket, orders: orders, page_title: "Orders", bulk_progress: nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    assign(socket, page_title: "New Order")
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Orders")
  end

  defp apply_action(socket, :bulk, _params) do
    assign(socket, page_title: "Bulk Simulation")
  end

  @impl true
  def handle_event("create_order", %{"order" => params}, socket) do
    case Manager.create_order(params) do
      {:ok, _order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Order created successfully")
         |> push_navigate(to: ~p"/")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create order: #{inspect(reason)}")}
    end
  end

  def handle_event("approve", %{"id" => id}, socket) do
    order_id = String.to_integer(id)

    case Manager.approve_order(order_id) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order approved")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to approve: #{inspect(reason)}")}
    end
  end

  def handle_event("start_bulk", %{"bulk" => params}, socket) do
    quantity = String.to_integer(params["quantity"])
    workers = String.to_integer(params["workers"])
    avg_time = String.to_integer(params["avg_time"])

    Task.start(fn ->
      RodarDemo.Workflow.BulkSimulator.run(quantity, workers, avg_time)
    end)

    {:noreply,
     socket
     |> assign(bulk_progress: %{phase: :creating, created: 0, total: quantity})
     |> put_flash(:info, "Bulk simulation started: #{quantity} orders, #{workers} workers")
     |> push_navigate(to: ~p"/")}
  end

  def handle_event("reject", %{"id" => id}, socket) do
    order_id = String.to_integer(id)

    case Manager.reject_order(order_id) do
      {:ok, _order} ->
        {:noreply, put_flash(socket, :info, "Order rejected")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reject: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:order_updated, _order}, socket) do
    # Debounce rapid updates during bulk simulation
    if socket.assigns[:refresh_timer] do
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    timer = Process.send_after(self(), :refresh_orders, 200)
    {:noreply, assign(socket, refresh_timer: timer)}
  end

  def handle_info(:refresh_orders, socket) do
    orders = Manager.list_orders()
    {:noreply, assign(socket, orders: orders, refresh_timer: nil)}
  end

  def handle_info({:bulk_progress, %{phase: :done}}, socket) do
    {:noreply, assign(socket, bulk_progress: nil)}
  end

  def handle_info({:bulk_progress, progress}, socket) do
    {:noreply, assign(socket, bulk_progress: progress)}
  end

  defp status_label(:completed), do: "Completed"
  defp status_label(:awaiting_approval), do: "Awaiting Approval"
  defp status_label(:rejected), do: "Rejected"
  defp status_label(:error), do: "Error"
  defp status_label(status), do: status |> to_string() |> String.capitalize()
end
