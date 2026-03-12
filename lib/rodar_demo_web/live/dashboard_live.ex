defmodule RodarDemoWeb.DashboardLive do
  use RodarDemoWeb, :live_view

  alias RodarDemo.Telemetry.Collector

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(RodarDemo.PubSub, Collector.topic())
    end

    snapshot = Collector.snapshot()
    bpmn_xml = load_bpmn_xml()

    {:ok,
     assign(socket,
       page_title: "Telemetry Dashboard",
       process_stats: snapshot.process_stats,
       node_stats: snapshot.node_stats,
       node_counts: build_node_counts(snapshot.node_stats),
       feed: snapshot.feed,
       bpmn_xml: bpmn_xml,
       refresh_timer: nil
     )}
  end

  @impl true
  def handle_event("reset", _params, socket) do
    Collector.reset()
    snapshot = Collector.snapshot()
    node_counts = build_node_counts(snapshot.node_stats)

    {:noreply,
     socket
     |> assign(
       process_stats: snapshot.process_stats,
       node_stats: snapshot.node_stats,
       node_counts: node_counts,
       feed: snapshot.feed
     )
     |> push_event("bpmn:update_counts", %{counts: node_counts})}
  end

  @impl true
  def handle_info(:dashboard_updated, socket) do
    # Debounce rapid updates
    if socket.assigns[:refresh_timer] do
      Process.cancel_timer(socket.assigns.refresh_timer)
    end

    timer = Process.send_after(self(), :refresh_dashboard, 200)
    {:noreply, assign(socket, refresh_timer: timer)}
  end

  def handle_info(:refresh_dashboard, socket) do
    snapshot = Collector.snapshot()
    node_counts = build_node_counts(snapshot.node_stats)

    socket =
      socket
      |> assign(
        process_stats: snapshot.process_stats,
        node_stats: snapshot.node_stats,
        node_counts: node_counts,
        feed: snapshot.feed,
        refresh_timer: nil
      )
      |> push_event("bpmn:update_counts", %{counts: node_counts})

    {:noreply, socket}
  end

  # Helper functions

  def format_duration_us(0), do: "-"

  def format_duration_us(us) when us < 1_000 do
    "#{us}us"
  end

  def format_duration_us(us) when us < 1_000_000 do
    "#{Float.round(us / 1_000, 1)}ms"
  end

  def format_duration_us(us) do
    "#{Float.round(us / 1_000_000, 2)}s"
  end

  def short_node_type(type) when is_atom(type) do
    type |> to_string() |> short_node_type()
  end

  def short_node_type(type) when is_binary(type) do
    type
    |> String.split(".")
    |> List.last()
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
  end

  defp load_bpmn_xml do
    Application.app_dir(:rodar_demo, "priv/bpmn/order_processing.bpmn")
    |> File.read!()
  end

  defp build_node_counts(node_stats) do
    Map.new(node_stats, fn stat -> {stat.node_id, stat.count} end)
  end
end
