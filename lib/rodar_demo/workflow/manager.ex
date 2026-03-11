defmodule RodarDemo.Workflow.Manager do
  use GenServer

  alias RodarBpmn.Engine.Diagram
  alias RodarBpmn.Context
  alias RodarBpmn.Activity.Task.User, as: UserTask

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def create_order(params) do
    GenServer.call(__MODULE__, {:create_order, params}, :infinity)
  end

  def approve_order(order_id) do
    GenServer.call(
      __MODULE__,
      {:complete_approval, order_id, %{"approved" => true, "approval_type" => "manager"}},
      :infinity
    )
  end

  def reject_order(order_id) do
    GenServer.call(
      __MODULE__,
      {:complete_approval, order_id, %{"approved" => false, "approval_type" => "manager"}},
      :infinity
    )
  end

  def list_orders do
    GenServer.call(__MODULE__, :list_orders)
  end

  def get_order(order_id) do
    GenServer.call(__MODULE__, {:get_order, order_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    table = :ets.new(:orders, [:set, :private])
    load_and_register_definition()
    {:ok, %{table: table, counter: 0}}
  end

  @impl true
  def handle_call({:create_order, params}, _from, state) do
    order_id = state.counter + 1
    amount = parse_amount(params["amount"] || params[:amount])
    customer = to_string(params["customer"] || params[:customer] || "")
    item = to_string(params["item"] || params[:item] || "")

    # Start process instance under the RodarBpmn supervisor
    case DynamicSupervisor.start_child(
           RodarBpmn.ProcessSupervisor,
           {RodarBpmn.Process, {"order_processing", %{}}}
         ) do
      {:ok, pid} ->
        context = RodarBpmn.Process.get_context(pid)

        # Populate data before activation
        Context.put_data(context, "customer", customer)
        Context.put_data(context, "item", item)
        Context.put_data(context, "amount", amount)
        Context.put_data(context, "order_id", order_id)

        # Activate the process (blocks until completion or user task)
        RodarBpmn.Process.activate(pid)
        process_status = RodarBpmn.Process.status(pid)

        status =
          case process_status do
            :completed -> :completed
            :suspended -> :awaiting_approval
            other -> other
          end

        order = %{
          id: order_id,
          customer: customer,
          item: item,
          amount: amount,
          process_pid: pid,
          status: status,
          created_at: DateTime.utc_now()
        }

        :ets.insert(state.table, {order_id, order})
        broadcast_update(order)
        {:reply, {:ok, order}, %{state | counter: order_id}}

      error ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:complete_approval, order_id, input}, _from, state) do
    case :ets.lookup(state.table, order_id) do
      [{^order_id, %{status: :awaiting_approval, process_pid: pid} = order}] ->
        context = RodarBpmn.Process.get_context(pid)
        process_map = Context.get(context, :process)

        # Find the user task element
        user_task_elem = Map.get(process_map, "Task_ManagerApproval")

        # Resume the user task with input data.
        # UserTask.resume/3 runs the rest of the flow synchronously.
        result = UserTask.resume(user_task_elem, context, input)

        status =
          case result do
            {:ok, _} ->
              if Context.get_data(context, "rejected") do
                :rejected
              else
                :completed
              end

            {:manual, _} ->
              :awaiting_approval

            {:error, _} ->
              :error

            _ ->
              :error
          end

        updated_order = %{order | status: status}
        :ets.insert(state.table, {order_id, updated_order})
        broadcast_update(updated_order)
        {:reply, {:ok, updated_order}, state}

      [{^order_id, _order}] ->
        {:reply, {:error, :not_awaiting_approval}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:list_orders, _from, state) do
    orders =
      :ets.tab2list(state.table)
      |> Enum.map(fn {_id, order} -> order end)
      |> Enum.sort_by(& &1.id, :desc)

    {:reply, orders, state}
  end

  def handle_call({:get_order, order_id}, _from, state) do
    case :ets.lookup(state.table, order_id) do
      [{^order_id, order}] -> {:reply, {:ok, order}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  # Private helpers

  defp load_and_register_definition do
    bpmn_path = Application.app_dir(:rodar_demo, "priv/bpmn/order_processing.bpmn")
    xml = File.read!(bpmn_path)
    diagram = Diagram.load(xml)
    [{:bpmn_process, attrs, elements}] = diagram.processes

    # Normalize script task elements (:scriptFormat -> :type) for the handler
    elements = normalize_script_tasks(elements)

    # Register service task handlers in TaskRegistry by element ID
    RodarBpmn.TaskRegistry.register("Task_Validate", RodarDemo.Workflow.Handlers.ValidateOrder)
    RodarBpmn.TaskRegistry.register("Task_Fulfill", RodarDemo.Workflow.Handlers.FulfillOrder)

    RodarBpmn.TaskRegistry.register(
      "Task_SendConfirmation",
      RodarDemo.Workflow.Handlers.SendConfirmation
    )

    RodarBpmn.TaskRegistry.register(
      "Task_NotifyRejection",
      RodarDemo.Workflow.Handlers.NotifyRejection
    )

    RodarBpmn.Registry.register("order_processing", {:bpmn_process, attrs, elements})
  end

  @script_output_variables %{
    "Task_AutoApprove" => "approved"
  }

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
