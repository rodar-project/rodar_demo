defmodule RodarDemo.Workflow.BulkSimulator do
  @moduledoc """
  Bulk order creation with simulated workers for user task processing.
  """

  alias RodarDemo.Workflow.Manager

  @customers ~w(Alice Bob Carlos Diana Eve Frank Grace Hank Iris Jack)
  @last_names ~w(Johnson Smith Rivera Chen Martinez Wilson Lee Brown Patel Taylor)
  @items [
    "Laptop",
    "Monitor",
    "Keyboard",
    "Mouse",
    "Headset",
    "Webcam",
    "Desk Chair",
    "Standing Desk",
    "USB Hub",
    "Docking Station"
  ]

  def run(quantity, num_workers, avg_time_seconds) do
    broadcast(%{phase: :creating, created: 0, total: quantity})

    for i <- 1..quantity do
      Manager.create_order(random_order_params())
      broadcast(%{phase: :creating, created: i, total: quantity})
    end

    broadcast(%{phase: :processing})

    for _ <- 1..num_workers do
      spawn(fn -> worker_loop(avg_time_seconds) end)
    end

    :ok
  end

  defp worker_loop(avg_time_seconds) do
    case find_pending() do
      nil ->
        Process.sleep(500)

        case find_pending() do
          nil -> broadcast(%{phase: :done})
          _order -> worker_loop(avg_time_seconds)
        end

      order ->
        Process.sleep(random_delay_ms(avg_time_seconds))

        if :rand.uniform() < 0.8 do
          Manager.approve_order(order.id)
        else
          Manager.reject_order(order.id)
        end

        worker_loop(avg_time_seconds)
    end
  end

  defp find_pending do
    Manager.list_orders()
    |> Enum.filter(&(&1.status == :awaiting_approval))
    |> case do
      [] -> nil
      orders -> Enum.random(orders)
    end
  end

  defp random_order_params do
    %{
      "customer" => "#{Enum.random(@customers)} #{Enum.random(@last_names)}",
      "item" => Enum.random(@items),
      "amount" => random_amount()
    }
  end

  defp random_amount do
    if :rand.uniform() < 0.5 do
      Float.round(:rand.uniform() * 999 + 1, 2)
    else
      Float.round(:rand.uniform() * 4000 + 1001, 2)
    end
  end

  defp random_delay_ms(avg_seconds) do
    z = (Enum.sum(for _ <- 1..6, do: :rand.uniform()) - 3.0) / 0.7071
    delay = avg_seconds + z * (avg_seconds / 3.0)
    max(round(delay * 1000), 100)
  end

  defp broadcast(payload) do
    Phoenix.PubSub.broadcast(RodarDemo.PubSub, "bulk_simulation", {:bulk_progress, payload})
  end
end
