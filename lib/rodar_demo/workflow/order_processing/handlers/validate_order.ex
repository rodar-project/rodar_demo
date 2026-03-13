defmodule RodarDemo.Workflow.OrderProcessing.Handlers.ValidateOrder do
  @moduledoc false

  @behaviour Rodar.Activity.Task.Service.Handler

  @impl true
  def execute(_attrs, data) do
    cond do
      not is_binary(data["customer"]) or data["customer"] == "" ->
        {:error, "Customer name is required"}

      not is_number(data["amount"]) or data["amount"] <= 0 ->
        {:error, "Amount must be greater than 0"}

      true ->
        {:ok, %{"validated" => true, "validated_at" => DateTime.utc_now() |> to_string()}}
    end
  end
end
