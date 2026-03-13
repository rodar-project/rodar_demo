defmodule RodarDemo.Telemetry.Collector do
  @moduledoc """
  GenServer + ETS metrics aggregator for BPMN telemetry events.

  Telemetry handlers write directly to public ETS tables (runs in caller process),
  then cast to GenServer for debounced PubSub broadcast.
  """
  use GenServer

  @process_stats :telemetry_process_stats
  @node_stats :telemetry_node_stats
  @feed :telemetry_feed
  @feed_max 50
  @broadcast_debounce 300

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def topic, do: "telemetry:dashboard"

  def snapshot do
    %{
      process_stats: read_process_stats(),
      node_stats: read_node_stats(),
      feed: read_feed()
    }
  end

  def reset do
    :ets.delete_all_objects(@process_stats)
    :ets.delete_all_objects(@node_stats)
    :ets.delete_all_objects(@feed)
    Phoenix.PubSub.broadcast(RodarDemo.PubSub, topic(), :dashboard_updated)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    :ets.new(@process_stats, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@node_stats, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@feed, [:ordered_set, :public, :named_table, read_concurrency: true])

    :telemetry.attach_many(
      "rodar-demo-collector",
      Rodar.Telemetry.events(),
      &__MODULE__.handle_event/4,
      nil
    )

    {:ok, %{broadcast_timer: nil}}
  end

  @impl true
  def handle_cast(:schedule_broadcast, state) do
    if state.broadcast_timer, do: Process.cancel_timer(state.broadcast_timer)
    timer = Process.send_after(self(), :broadcast, @broadcast_debounce)
    {:noreply, %{state | broadcast_timer: timer}}
  end

  @impl true
  def handle_info(:broadcast, state) do
    Phoenix.PubSub.broadcast(RodarDemo.PubSub, topic(), :dashboard_updated)
    {:noreply, %{state | broadcast_timer: nil}}
  end

  # Telemetry handlers (run in caller process)

  def handle_event([:rodar, :process, :start], _measurements, metadata, _config) do
    :ets.update_counter(@process_stats, :total, 1, {:total, 0})
    :ets.update_counter(@process_stats, :active, 1, {:active, 0})
    add_feed_entry("Process #{short_id(metadata.instance_id)} started")
    schedule_broadcast()
  end

  def handle_event([:rodar, :process, :stop], %{duration: duration}, metadata, _config) do
    :ets.update_counter(@process_stats, :active, -1, {:active, 0})
    status = metadata[:status] || :completed

    :ets.update_counter(@process_stats, status, 1, {status, 0})
    update_duration_stats(@process_stats, :duration, duration)

    add_feed_entry("Process #{short_id(metadata.instance_id)} #{status}")
    schedule_broadcast()
  end

  def handle_event([:rodar, :node, :start], _measurements, metadata, _config) do
    add_feed_entry("#{metadata.node_type} #{metadata.node_id} started")
    schedule_broadcast()
  end

  def handle_event([:rodar, :node, :stop], %{duration: duration}, metadata, _config) do
    node_key = {metadata.node_id, metadata.node_type}

    # Update count
    :ets.update_counter(@node_stats, node_key, {2, 1}, {node_key, 0, 0, 0, 0})
    # Update sum
    :ets.update_counter(@node_stats, node_key, {3, duration}, {node_key, 0, 0, 0, 0})

    update_node_min_max(node_key, duration)

    result = metadata[:result]
    label = if result, do: " (#{inspect(result)})", else: ""
    add_feed_entry("#{metadata.node_type} #{metadata.node_id} completed#{label}")
    schedule_broadcast()
  end

  def handle_event([:rodar, :node, :exception], _measurements, metadata, _config) do
    :ets.update_counter(@process_stats, :errors, 1, {:errors, 0})

    add_feed_entry(
      "ERROR: #{metadata.node_type} #{metadata.node_id} - #{inspect(metadata.reason)}"
    )

    schedule_broadcast()
  end

  def handle_event(_event, _measurements, _metadata, _config) do
    :ok
  end

  # Private helpers

  defp schedule_broadcast do
    GenServer.cast(__MODULE__, :schedule_broadcast)
  end

  defp add_feed_entry(message) do
    key = -System.monotonic_time()
    timestamp = DateTime.utc_now()
    :ets.insert(@feed, {key, timestamp, message})
    trim_feed()
  end

  defp trim_feed do
    size = :ets.info(@feed, :size)

    if size > @feed_max do
      # Delete oldest entries (largest keys in negated monotonic time)
      keys =
        :ets.foldl(fn {key, _, _}, acc -> [key | acc] end, [], @feed)
        |> Enum.sort()
        |> Enum.take(size - @feed_max)

      Enum.each(keys, &:ets.delete(@feed, &1))
    end
  end

  defp update_duration_stats(table, key, duration) do
    case :ets.lookup(table, key) do
      [{^key, sum, count, min, max}] ->
        new_min = min(min, duration)
        new_max = max(max, duration)
        :ets.insert(table, {key, sum + duration, count + 1, new_min, new_max})

      [] ->
        :ets.insert(table, {key, duration, 1, duration, duration})
    end
  end

  defp update_node_min_max(node_key, duration) do
    case :ets.lookup(@node_stats, node_key) do
      [{^node_key, count, sum, min_val, max_val}] ->
        new_min = if min_val == 0, do: duration, else: min(min_val, duration)
        new_max = max(max_val, duration)
        :ets.insert(@node_stats, {node_key, count, sum, new_min, new_max})

      [] ->
        :ok
    end
  end

  defp read_process_stats do
    stats = :ets.tab2list(@process_stats)

    %{
      total: get_stat(stats, :total),
      active: get_stat(stats, :active),
      completed: get_stat(stats, :completed),
      errors: get_stat(stats, :errors),
      duration: get_duration_stat(stats, :duration)
    }
  end

  defp read_node_stats do
    :ets.tab2list(@node_stats)
    |> Enum.map(fn {{node_id, node_type}, count, sum, min_val, max_val} ->
      avg = if count > 0, do: div(sum, count), else: 0

      %{
        node_id: node_id,
        node_type: node_type,
        count: count,
        avg: avg,
        min: min_val,
        max: max_val
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
  end

  defp read_feed do
    :ets.tab2list(@feed)
    |> Enum.sort_by(fn {key, _, _} -> key end)
    |> Enum.map(fn {_key, timestamp, message} ->
      %{timestamp: timestamp, message: message}
    end)
  end

  defp get_stat(stats, key) do
    case List.keyfind(stats, key, 0) do
      {^key, value} -> value
      _ -> 0
    end
  end

  defp get_duration_stat(stats, key) do
    case List.keyfind(stats, key, 0) do
      {^key, sum, count, min, max} ->
        avg = if count > 0, do: div(sum, count), else: 0
        %{avg: avg, min: min, max: max, count: count}

      _ ->
        %{avg: 0, min: 0, max: 0, count: 0}
    end
  end

  defp short_id(id) when is_binary(id) do
    id |> String.split("-") |> List.first() |> String.slice(0, 8)
  end

  defp short_id(id), do: inspect(id)
end
