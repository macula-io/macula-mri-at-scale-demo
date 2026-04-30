defmodule MriDemo.DemoServer do
  @moduledoc """
  GenServer managing demo state with PubSub broadcasts.
  """
  use GenServer

  alias MriDemo.Mri.{Store, Generator}

  @pubsub MriDemo.PubSub
  @topic "demo:state"

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def set_scale(scale) when is_number(scale) do
    GenServer.cast(__MODULE__, {:set_scale, scale})
  end

  def init_store, do: GenServer.call(__MODULE__, :init_store)

  def generate, do: GenServer.cast(__MODULE__, :generate)

  def clear, do: GenServer.cast(__MODULE__, :clear)

  def benchmark, do: GenServer.cast(__MODULE__, :benchmark)

  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    state = %{
      scale: 0.10,
      status: :idle,
      store_ready: false,
      progress: %{},
      region_stats: %{},
      metrics: %{},
      metrics_history: [],  # Time series: [{total_mris, lookup_us, stats_ms}]
      message: "Ready to generate network"
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:init_store, _from, state) do
    case Store.start() do
      {:ok, _} ->
        new_state = %{state | store_ready: true, message: "Store initialized. Ready to generate!"}
        broadcast(new_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        new_state = %{state | message: "Failed to start store: #{inspect(reason)}"}
        broadcast(new_state)
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_cast({:set_scale, scale}, state) do
    expected = Generator.expected_counts(scale)
    message = format_expected(expected)
    new_state = %{state | scale: scale, message: message}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:generate, %{store_ready: false} = state) do
    new_state = %{state | message: "Please initialize the store first"}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:generate, %{status: :generating} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast(:generate, state) do
    new_state = %{state | status: :generating, progress: %{}, region_stats: %{}, metrics_history: []}
    broadcast(new_state)

    pid = self()
    Task.start(fn ->
      Generator.generate(state.scale, progress_callback: fn region, phase, current, total ->
        send(pid, {:progress, region, phase, current, total})
      end)
      send(pid, :generation_complete)
    end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear, %{store_ready: true} = state) do
    Store.stop()
    Store.start()
    new_state = %{state | status: :idle, region_stats: %{}, metrics: %{}, message: "Network cleared"}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:clear, state), do: {:noreply, state}

  @impl true
  def handle_cast(:benchmark, %{status: :ready} = state) do
    new_state = %{state | message: "Running benchmark..."}
    broadcast(new_state)

    pid = self()
    Task.start(fn ->
      metrics = run_benchmarks()
      send(pid, {:benchmark_complete, metrics})
    end)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:benchmark, state) do
    new_state = %{state | message: "Generate a network first"}
    broadcast(new_state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:progress, region, phase, current, total}, state) do
    progress = Map.put(state.progress, {region, phase}, {current, total})

    region_stats =
      case phase do
        :srps ->
          put_in(state.region_stats, [Access.key(region, %{}), :srps], current)
        :homes ->
          put_in(state.region_stats, [Access.key(region, %{}), :homes], current)
        :complete ->
          put_in(state.region_stats, [Access.key(region, %{}), :status], :complete)
        _ ->
          state.region_stats
      end

    # Sample metrics periodically during generation
    total_mris = count_total_mris(region_stats)
    metrics_history = maybe_sample_metrics(state.metrics_history, total_mris)

    message = "#{String.capitalize(region)}: #{phase} #{current}/#{total}"
    new_state = %{state | progress: progress, region_stats: region_stats, message: message, metrics_history: metrics_history}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:generation_complete, state) do
    stats = Store.get_stats()
    message = "Generation complete: #{format_number(stats.srp_count)} SRPs, #{format_number(stats.home_count)} homes"
    new_state = %{state | status: :ready, message: message}
    broadcast(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:benchmark_complete, metrics}, state) do
    new_state = %{state | metrics: metrics, message: "Benchmark complete"}
    broadcast(new_state)
    {:noreply, new_state}
  end

  ## Private

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:demo_state, state})
  end

  defp run_benchmarks do
    sample_mris =
      for region <- ["brussels", "flanders", "wallonia"],
          n <- 1..10 do
        srp_id = String.pad_leading("#{n}", 6, "0")
        "mri:srp:be.proximus/#{region}/srp-#{srp_id}"
      end

    {lookup_time, _} = :timer.tc(fn ->
      Enum.each(sample_mris, &Store.lookup/1)
    end)
    avg_lookup = lookup_time / length(sample_mris)

    {stats_time, _} = :timer.tc(fn ->
      Store.get_stats()
    end)

    {region_time, _} = :timer.tc(fn ->
      Store.get_region_stats()
    end)

    %{
      lookup_us: Float.round(avg_lookup, 1),
      type_query_ms: Float.round(stats_time / 1000, 2),
      region_query_ms: Float.round(region_time / 1000, 2)
    }
  end

  defp count_total_mris(region_stats) do
    Enum.reduce(region_stats, 0, fn {_, stats}, acc ->
      acc + Map.get(stats, :srps, 0) + Map.get(stats, :homes, 0)
    end)
  end

  # Sample metrics every ~500 MRIs (or first sample at 10)
  defp maybe_sample_metrics(history, total_mris) when total_mris < 10, do: history
  defp maybe_sample_metrics([], total_mris), do: [sample_metrics(total_mris)]
  defp maybe_sample_metrics(history, total_mris) do
    last_sample = List.last(history)
    sample_interval = max(500, div(total_mris, 50))  # ~50 data points max

    if total_mris - last_sample.total >= sample_interval do
      history ++ [sample_metrics(total_mris)]
    else
      history
    end
  end

  defp sample_metrics(total_mris) do
    # Quick lookup benchmark on a few random-ish MRIs
    sample_mris = for n <- 1..5 do
      srp_id = String.pad_leading("#{rem(n * 7, 100) + 1}", 6, "0")
      "mri:srp:be.proximus/brussels/srp-#{srp_id}"
    end

    {lookup_time, _} = :timer.tc(fn ->
      Enum.each(sample_mris, &Store.lookup/1)
    end)

    {stats_time, _} = :timer.tc(fn ->
      Store.get_stats()
    end)

    %{
      total: total_mris,
      lookup_us: Float.round(lookup_time / length(sample_mris), 1),
      stats_ms: Float.round(stats_time / 1000, 2),
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  defp format_expected(expected) do
    "At #{round(expected.scale * 100)}%: ~#{format_number(expected.total_srps)} SRPs, ~#{format_number(expected.total_homes)} homes"
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: "#{n}"
end
