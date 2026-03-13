defmodule RodarDemo.Workflow.OrderProcessing.Manager do
  use Rodar.Workflow.Server,
    bpmn_file: "priv/bpmn/order_processing.bpmn",
    process_id: "order_processing",
    otp_app: :rodar_demo,
    app_name: "RodarDemo"

  alias Rodar.Engine.Diagram
  alias Rodar.Scaffold.Discovery

  @script_output_variables %{"Task_AutoApprove" => "approved"}

  # --- Workflow Callbacks ---

  @impl Rodar.Workflow.Server
  def init_data(params, instance_id) do
    %{
      "customer" => to_string(params["customer"] || params[:customer] || ""),
      "item" => to_string(params["item"] || params[:item] || ""),
      "amount" => parse_amount(params["amount"] || params[:amount]),
      "order_id" => instance_id
    }
  end

  @impl Rodar.Workflow.Server
  def map_status(:suspended), do: :awaiting_approval
  def map_status(other), do: other

  # Override setup for script task normalization
  def setup do
    bpmn_path = Application.app_dir(:rodar_demo, "priv/bpmn/order_processing.bpmn")

    with {:ok, xml} <- File.read(bpmn_path) do
      diagram = Diagram.load(xml, bpmn_file: "order_processing.bpmn", app_name: "RodarDemo")
      [{:bpmn_process, attrs, elements}] = diagram.processes
      elements = normalize_script_tasks(elements)

      Rodar.Registry.register("order_processing", {:bpmn_process, attrs, elements})

      if discovery = Map.get(diagram, :discovery) do
        Discovery.register_discovered(discovery)
      end

      {:ok, diagram}
    end
  end

  # --- Domain API ---

  def create_order(params) do
    case create_instance(params) do
      {:ok, instance} ->
        order = enrich_instance(instance)
        broadcast_update(order)
        {:ok, order}

      error ->
        error
    end
  end

  def approve_order(order_id) do
    case complete_task(order_id, "Task_ManagerApproval", %{
           "approved" => true,
           "approval_type" => "manager"
         }) do
      {:ok, instance} ->
        order = enrich_instance(instance)
        broadcast_update(order)
        {:ok, order}

      error ->
        error
    end
  end

  def reject_order(order_id) do
    case complete_task(order_id, "Task_ManagerApproval", %{
           "approved" => false,
           "approval_type" => "manager"
         }) do
      {:ok, instance} ->
        data = process_data(instance.process_pid)

        status =
          if data["rejected"],
            do: :rejected,
            else: instance.status

        order = enrich_instance(%{instance | status: status})
        broadcast_update(order)
        {:ok, order}

      error ->
        error
    end
  end

  def list_orders do
    list_instances() |> Enum.map(&enrich_instance/1)
  end

  def get_order(id) do
    case get_instance(id) do
      {:ok, instance} -> {:ok, enrich_instance(instance)}
      error -> error
    end
  end

  # --- Private Helpers ---

  defp enrich_instance(instance) do
    data = process_data(instance.process_pid)

    Map.merge(instance, %{
      customer: data["customer"] || "",
      item: data["item"] || "",
      amount: data["amount"] || 0
    })
  end

  defp normalize_script_tasks(elements) do
    Map.new(elements, fn
      {id, {:bpmn_activity_task_script, %{scriptFormat: format} = attrs}} ->
        attrs =
          attrs
          |> Map.delete(:scriptFormat)
          |> Map.put(:type, format)
          |> then(fn a ->
            case Map.get(@script_output_variables, id) do
              nil -> a
              var -> Map.put(a, :output_variable, var)
            end
          end)

        {id, {:bpmn_activity_task_script, attrs}}

      {id, elem} ->
        {id, elem}
    end)
  end

  defp broadcast_update(order) do
    Phoenix.PubSub.broadcast(RodarDemo.PubSub, "orders", {:order_updated, order})
  end

  defp parse_amount(val) when is_number(val), do: val

  defp parse_amount(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_amount(_), do: 0
end
