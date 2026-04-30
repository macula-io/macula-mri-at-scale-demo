defmodule MriDemoWeb.DemoLive do
  use MriDemoWeb, :live_view

  alias MriDemo.DemoServer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: DemoServer.subscribe()
    state = DemoServer.get_state()

    {:ok,
     socket
     |> assign_state(state)
     |> assign(:active_tab, "map")}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) when tab in ["map", "stats", "khepri"] do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("init_store", _, socket) do
    DemoServer.init_store()
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_scale", %{"scale" => scale_str}, socket) do
    case Float.parse(scale_str) do
      {scale, _} -> DemoServer.set_scale(scale)
      :error -> :ok
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("generate", _, socket) do
    DemoServer.generate()
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear", _, socket) do
    DemoServer.clear()
    {:noreply, socket}
  end

  @impl true
  def handle_event("benchmark", _, socket) do
    DemoServer.benchmark()
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: "/?tab=#{tab}")}
  end

  @impl true
  def handle_info({:demo_state, state}, socket) do
    socket = assign_state(socket, state)

    socket =
      if length(state.metrics_history) > 0 do
        push_event(socket, "metrics-update", %{data: state.metrics_history})
      else
        socket
      end

    # Push markers to map if on map tab
    socket =
      if socket.assigns.active_tab == "map" do
        markers = build_markers(state.region_stats)
        push_event(socket, "update-markers", %{markers: markers})
      else
        socket
      end

    {:noreply, socket}
  end

  defp assign_state(socket, state) do
    assign(socket,
      scale: state.scale,
      status: state.status,
      store_ready: state.store_ready,
      progress: state.progress,
      region_stats: state.region_stats,
      metrics: state.metrics,
      metrics_history: state.metrics_history,
      message: state.message
    )
  end

  defp build_markers(region_stats) do
    Enum.flat_map(region_stats, fn {region, stats} ->
      cities = get_region_cities(region)
      srp_count = min(Map.get(stats, :srps, 0), 200)
      home_count = min(div(Map.get(stats, :homes, 0), 500), 400)

      # Distribute SRPs across cities in this region
      srp_markers =
        for i <- 1..max(srp_count, 1) do
          city = Enum.at(cities, rem(i - 1, length(cities)))
          {lat, lng} = jitter_point(city, 0.02, {region, :srp, i})
          %{type: "srp", lat: lat, lng: lng, region: region}
        end

      # Cluster homes around SRPs
      home_markers =
        for i <- 1..max(home_count, 1) do
          # Pick a random SRP to cluster around
          srp_idx = rem(:erlang.phash2({region, :home_srp, i}), max(srp_count, 1))
          srp = Enum.at(srp_markers, srp_idx) || %{lat: 50.5, lng: 4.5}
          {lat, lng} = jitter_point({srp.lat, srp.lng}, 0.008, {region, :home, i})
          %{type: "home", lat: lat, lng: lng, region: region}
        end

      srp_markers ++ home_markers
    end)
  end

  # Real Belgian cities/towns with coordinates
  defp get_region_cities("flanders") do
    [
      {51.2194, 4.4025},  # Antwerp
      {51.0543, 3.7174},  # Ghent
      {51.2093, 3.2247},  # Bruges
      {50.8798, 4.7005},  # Leuven
      {51.0259, 4.4776},  # Mechelen
      {50.9369, 4.0367},  # Aalst
      {50.8279, 3.2649},  # Kortrijk
      {50.9307, 5.3378},  # Hasselt
      {51.1565, 4.1434},  # Sint-Niklaas
      {50.9654, 5.5012},  # Genk
      {50.9446, 3.1257},  # Roeselare
      {51.0300, 3.5100},  # Dendermonde
      {51.1833, 4.9333},  # Turnhout
      {50.9281, 5.0958},  # Diest
      {51.0167, 3.1333},  # Tielt
      {51.0989, 3.9894},  # Lokeren
      {50.8503, 3.6167},  # Oudenaarde
      {51.1308, 4.3372},  # Temse
      {50.9833, 5.1833},  # Beringen
      {51.2333, 4.8333},  # Mol
    ]
  end

  defp get_region_cities("brussels") do
    [
      {50.8503, 4.3517},  # Brussels City
      {50.8667, 4.3833},  # Schaerbeek
      {50.8333, 4.3000},  # Anderlecht
      {50.8278, 4.3778},  # Ixelles
      {50.8214, 4.3989},  # Etterbeek
      {50.8667, 4.3333},  # Molenbeek
      {50.8500, 4.4167},  # Woluwe-Saint-Lambert
      {50.8333, 4.4333},  # Auderghem
      {50.8000, 4.3500},  # Forest
      {50.8167, 4.3167},  # Saint-Gilles
      {50.8833, 4.3667},  # Evere
      {50.8667, 4.4167},  # Woluwe-Saint-Pierre
    ]
  end

  defp get_region_cities("wallonia") do
    [
      {50.6326, 5.5797},  # Liège
      {50.4108, 4.4446},  # Charleroi
      {50.4669, 4.8675},  # Namur
      {50.4542, 3.9523},  # Mons
      {50.4795, 4.1854},  # La Louvière
      {50.6058, 3.3883},  # Tournai
      {50.4136, 4.6108},  # Sambreville
      {50.5972, 5.8567},  # Verviers
      {50.4167, 4.0333},  # Binche
      {50.2500, 5.0000},  # Dinant
      {49.6833, 5.8167},  # Arlon
      {50.0833, 5.3667},  # Marche-en-Famenne
      {50.4875, 3.8108},  # Ath
      {50.4667, 4.2833},  # Manage
      {50.5500, 4.3500},  # Nivelles
      {50.3667, 4.8333},  # Fosses-la-Ville
    ]
  end

  defp get_region_cities(_), do: [{50.5, 4.5}]

  # Add random jitter to a point (for realistic distribution)
  defp jitter_point({lat, lng}, radius, seed) do
    h = :erlang.phash2(seed)
    angle = rem(h, 360) * :math.pi() / 180
    dist = rem(div(h, 360), 1000) / 1000 * radius
    new_lat = lat + dist * :math.cos(angle)
    new_lng = lng + dist * :math.sin(angle) * 1.5  # Adjust for latitude
    {Float.round(new_lat, 5), Float.round(new_lng, 5)}
  end

  defp format_number(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 1)}M"
  defp format_number(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n), do: "#{n}"

  defp total_srps(stats), do: Enum.reduce(stats, 0, fn {_, s}, acc -> acc + Map.get(s, :srps, 0) end)
  defp total_homes(stats), do: Enum.reduce(stats, 0, fn {_, s}, acc -> acc + Map.get(s, :homes, 0) end)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 flex flex-col">
      <!-- Fixed Header with Controls -->
      <header class="bg-slate-800 border-b border-slate-700 sticky top-0 z-50">
        <!-- Title Bar -->
        <div class="px-6 py-3 border-b border-slate-700/50">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold bg-gradient-to-r from-cyan-400 to-purple-400 bg-clip-text text-transparent">
                Macula MRI at Scale
              </h1>
              <p class="text-sm text-slate-400">Proximus Network Simulation</p>
            </div>

            <!-- Live Stats -->
            <div class="flex items-center gap-8">
              <div class="text-center">
                <div class="text-2xl font-bold text-cyan-400"><%= format_number(total_srps(@region_stats)) %></div>
                <div class="text-xs text-slate-400 uppercase tracking-wide">SRPs</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-purple-400"><%= format_number(total_homes(@region_stats)) %></div>
                <div class="text-xs text-slate-400 uppercase tracking-wide">Homes</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold text-amber-400"><%= round(@scale * 100) %>%</div>
                <div class="text-xs text-slate-400 uppercase tracking-wide">Scale</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Control Bar -->
        <div class="px-6 py-3 flex items-center gap-6">
          <!-- Scale Slider -->
          <div class="flex-1 max-w-md">
            <form phx-change="set_scale" class="flex items-center gap-3">
              <span class="text-sm text-slate-400 w-12">Scale</span>
              <input
                type="range"
                min="0.01"
                max="1.0"
                step="0.01"
                value={@scale}
                name="scale"
                class="flex-1 h-2 bg-slate-700 rounded-lg appearance-none cursor-pointer accent-cyan-500"
              />
              <span class="text-sm text-cyan-400 font-mono w-12"><%= round(@scale * 100) %>%</span>
            </form>
          </div>

          <!-- Action Buttons -->
          <div class="flex items-center gap-2">
            <button
              :if={!@store_ready}
              phx-click="init_store"
              class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-500 transition-colors"
            >
              Initialize Store
            </button>
            <button
              :if={@store_ready && @status != :generating}
              phx-click="generate"
              class="px-4 py-2 bg-cyan-600 text-white text-sm font-medium rounded-lg hover:bg-cyan-500 transition-colors"
            >
              Generate Network
            </button>
            <button
              :if={@status == :generating}
              disabled
              class="px-4 py-2 bg-slate-600 text-slate-400 text-sm font-medium rounded-lg cursor-not-allowed flex items-center gap-2"
            >
              <span class="w-4 h-4 border-2 border-slate-400 border-t-transparent rounded-full animate-spin"></span>
              Generating...
            </button>
            <button
              :if={@status == :ready}
              phx-click="benchmark"
              class="px-4 py-2 bg-amber-600 text-white text-sm font-medium rounded-lg hover:bg-amber-500 transition-colors"
            >
              Benchmark
            </button>
            <button
              :if={@store_ready}
              phx-click="clear"
              class="px-4 py-2 bg-slate-700 text-slate-300 text-sm font-medium rounded-lg hover:bg-slate-600 transition-colors"
            >
              Clear
            </button>
          </div>

          <!-- Status Message -->
          <div class="flex-1 text-right">
            <span class="text-sm text-slate-400"><%= @message %></span>
          </div>
        </div>

        <!-- Tab Navigation -->
        <div class="px-6 flex items-center gap-1 border-t border-slate-700/50">
          <button
            phx-click="switch_tab"
            phx-value-tab="map"
            class={"px-5 py-3 text-sm font-medium transition-colors border-b-2 -mb-px " <>
              if(@active_tab == "map", do: "text-cyan-400 border-cyan-400", else: "text-slate-400 border-transparent hover:text-white")}
          >
            🗺️ Network Map
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="stats"
            class={"px-5 py-3 text-sm font-medium transition-colors border-b-2 -mb-px " <>
              if(@active_tab == "stats", do: "text-cyan-400 border-cyan-400", else: "text-slate-400 border-transparent hover:text-white")}
          >
            📊 Statistics
          </button>
          <button
            phx-click="switch_tab"
            phx-value-tab="khepri"
            class={"px-5 py-3 text-sm font-medium transition-colors border-b-2 -mb-px " <>
              if(@active_tab == "khepri", do: "text-cyan-400 border-cyan-400", else: "text-slate-400 border-transparent hover:text-white")}
          >
            🌳 Khepri Browser
          </button>
        </div>
      </header>

      <!-- Content Area -->
      <main class="flex-1 relative" style="height: calc(100vh - 180px);">
        <%= case @active_tab do %>
          <% "map" -> %>
            <.map_tab region_stats={@region_stats} status={@status} />
          <% "stats" -> %>
            <.stats_tab region_stats={@region_stats} metrics={@metrics} metrics_history={@metrics_history} status={@status} />
          <% "khepri" -> %>
            <.khepri_tab region_stats={@region_stats} store_ready={@store_ready} />
        <% end %>
      </main>
    </div>
    """
  end

  # ============================================================================
  # MAP TAB
  # ============================================================================
  defp map_tab(assigns) do
    ~H"""
    <div class="absolute inset-0">
      <div
        id="belgium-map"
        phx-hook="BelgiumMap"
        phx-update="ignore"
        class="w-full h-full"
        data-initial-markers={Jason.encode!(build_markers(@region_stats))}
      >
      </div>

      <!-- Legend Overlay -->
      <div class="absolute bottom-6 left-6 bg-slate-800/95 backdrop-blur rounded-xl p-4 border border-slate-700 shadow-xl">
        <h3 class="text-white font-semibold mb-3 text-sm">Legend</h3>
        <div class="space-y-2">
          <div class="flex items-center gap-3">
            <div class="w-3 h-3 rounded-full bg-cyan-400 shadow-lg shadow-cyan-400/50"></div>
            <span class="text-slate-300 text-xs">SRP Node</span>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-2 h-2 rounded-full bg-purple-400 opacity-70"></div>
            <span class="text-slate-300 text-xs">Home</span>
          </div>
        </div>
        <div class="mt-3 pt-3 border-t border-slate-700 space-y-1">
          <div class="flex items-center gap-2 text-xs">
            <div class="w-2 h-2 rounded-full bg-cyan-400"></div>
            <span class="text-slate-400">Flanders</span>
          </div>
          <div class="flex items-center gap-2 text-xs">
            <div class="w-2 h-2 rounded-full bg-amber-400"></div>
            <span class="text-slate-400">Brussels</span>
          </div>
          <div class="flex items-center gap-2 text-xs">
            <div class="w-2 h-2 rounded-full bg-purple-400"></div>
            <span class="text-slate-400">Wallonia</span>
          </div>
        </div>
      </div>

      <!-- Status Overlay -->
      <%= if @status == :generating do %>
        <div class="absolute top-4 right-4 bg-emerald-500/90 backdrop-blur rounded-lg px-4 py-2 flex items-center gap-2 shadow-lg">
          <div class="w-3 h-3 bg-white rounded-full animate-pulse"></div>
          <span class="text-white font-medium text-sm">Generating...</span>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # STATS TAB
  # ============================================================================
  defp stats_tab(assigns) do
    ~H"""
    <div class="h-full overflow-auto p-6">
      <div class="max-w-6xl mx-auto grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Region Statistics -->
        <div class="bg-slate-800 rounded-xl border border-slate-700 p-5">
          <h2 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <span>📊</span> Region Statistics
          </h2>
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-700">
                <th class="text-left py-2 text-slate-400 font-medium">Region</th>
                <th class="text-right py-2 text-slate-400 font-medium">SRPs</th>
                <th class="text-right py-2 text-slate-400 font-medium">Homes</th>
              </tr>
            </thead>
            <tbody>
              <%= for {region, stats} <- @region_stats do %>
                <tr class="border-b border-slate-700/50">
                  <td class="py-3">
                    <div class="flex items-center gap-2">
                      <div class={"w-2 h-2 rounded-full " <> region_dot_color(region)}></div>
                      <span class="text-white capitalize"><%= region %></span>
                    </div>
                  </td>
                  <td class="py-3 text-right text-cyan-400 font-mono">
                    <%= format_number(Map.get(stats, :srps, 0)) %>
                  </td>
                  <td class="py-3 text-right text-purple-400 font-mono">
                    <%= format_number(Map.get(stats, :homes, 0)) %>
                  </td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr class="bg-slate-700/30">
                <td class="py-3 font-bold text-white">Total</td>
                <td class="py-3 text-right text-cyan-400 font-mono font-bold">
                  <%= format_number(total_srps(@region_stats)) %>
                </td>
                <td class="py-3 text-right text-purple-400 font-mono font-bold">
                  <%= format_number(total_homes(@region_stats)) %>
                </td>
              </tr>
            </tfoot>
          </table>
        </div>

        <!-- Performance Chart -->
        <div class="lg:col-span-2 bg-slate-800 rounded-xl border border-slate-700 p-5">
          <h2 class="text-lg font-semibold text-white mb-4 flex items-center gap-2">
            <span>⚡</span> Performance
          </h2>

          <%= if @status == :generating or length(@metrics_history) > 0 do %>
            <div id="metrics-chart" phx-hook="MetricsChart" phx-update="ignore" class="h-64"></div>
            <%= if length(@metrics_history) > 0 do %>
              <% last = List.last(@metrics_history) %>
              <div class="mt-4 grid grid-cols-2 gap-3">
                <div class="bg-slate-700/50 rounded-lg p-3">
                  <span class="text-slate-400 text-xs">Total MRIs</span>
                  <p class="text-xl font-bold text-white"><%= format_number(last.total) %></p>
                </div>
                <div class="bg-slate-700/50 rounded-lg p-3">
                  <span class="text-slate-400 text-xs">Lookup Time</span>
                  <p class="text-xl font-bold text-cyan-400"><%= last.lookup_us %> µs</p>
                </div>
              </div>
            <% end %>
          <% else %>
            <%= if map_size(@metrics) > 0 do %>
              <div class="space-y-4">
                <.metric_bar label="SRP Lookup" value={@metrics.lookup_us} unit="µs" max={500} color="cyan" />
                <.metric_bar label="Type Query" value={@metrics.type_query_ms} unit="ms" max={50} color="purple" />
                <.metric_bar label="Region Stats" value={@metrics.region_query_ms} unit="ms" max={100} color="amber" />
              </div>
            <% else %>
              <div class="flex flex-col items-center justify-center h-48 text-slate-500">
                <span class="text-4xl mb-4">📊</span>
                <p>Generate a network to see metrics</p>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- About -->
        <div class="lg:col-span-3 bg-slate-800/50 rounded-xl border border-slate-700 p-5">
          <h3 class="text-sm font-semibold text-slate-300 mb-4">About This Demo</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-slate-400">
            <div class="flex items-start gap-3">
              <span class="text-cyan-400 text-lg">📡</span>
              <div>
                <p class="font-medium text-white">Street Relay Points (SRPs)</p>
                <p>~4,000 at full scale, serving neighborhood clusters</p>
              </div>
            </div>
            <div class="flex items-start gap-3">
              <span class="text-purple-400 text-lg">🏠</span>
              <div>
                <p class="font-medium text-white">Home Connections</p>
                <p>~1,000,000 at full scale, ~250 homes per SRP</p>
              </div>
            </div>
            <div class="flex items-start gap-3">
              <span class="text-amber-400 text-lg">🗄️</span>
              <div>
                <p class="font-medium text-white">Khepri Storage</p>
                <p>Raft-consensus tree-based distributed store</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp metric_bar(assigns) do
    percent = min(100, assigns.value / assigns.max * 100)
    assigns = assign(assigns, :percent, percent)

    ~H"""
    <div>
      <div class="flex justify-between items-center mb-1">
        <span class="text-sm text-slate-400"><%= @label %></span>
        <span class={"text-sm font-mono text-#{@color}-400"}><%= @value %> <%= @unit %></span>
      </div>
      <div class="h-2 bg-slate-700 rounded-full overflow-hidden">
        <div class={"h-full bg-#{@color}-500 rounded-full transition-all duration-300"} style={"width: #{@percent}%"}></div>
      </div>
    </div>
    """
  end

  defp region_dot_color("flanders"), do: "bg-cyan-400"
  defp region_dot_color("brussels"), do: "bg-amber-400"
  defp region_dot_color("wallonia"), do: "bg-purple-400"
  defp region_dot_color(_), do: "bg-slate-400"

  # ============================================================================
  # KHEPRI TAB
  # ============================================================================
  defp khepri_tab(assigns) do
    tree = build_khepri_tree(assigns.region_stats, assigns.store_ready)
    assigns = assign(assigns, :tree, tree)

    ~H"""
    <div class="h-full flex">
      <!-- Tree Browser Sidebar -->
      <div class="w-80 bg-slate-800 border-r border-slate-700 flex flex-col">
        <div class="p-4 border-b border-slate-700">
          <h2 class="text-lg font-semibold text-white flex items-center gap-2">
            <span>🌳</span> Khepri Store
          </h2>
          <p class="text-xs text-slate-400 mt-1">Distributed data structure</p>
        </div>
        <div class="flex-1 overflow-auto p-3">
          <%= if @store_ready && @tree do %>
            <.tree_node node={@tree} depth={0} />
          <% else %>
            <div class="text-center py-8 text-slate-500">
              <p>Store not initialized</p>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Main Content -->
      <div class="flex-1 p-6 overflow-auto">
        <div class="max-w-4xl">
          <h3 class="text-lg font-semibold text-white mb-4">Store Structure</h3>

          <div class="bg-slate-800 rounded-xl border border-slate-700 overflow-hidden">
            <div class="px-4 py-3 bg-slate-700/50 border-b border-slate-700">
              <code class="text-cyan-400 font-mono text-sm">:mri_demo_store</code>
            </div>
            <div class="p-4 font-mono text-sm text-slate-300 space-y-1">
              <p>├── <span class="text-blue-400">mri/</span></p>
              <p>│   ├── <span class="text-cyan-400">srp/</span> <span class="text-slate-500">(<%= format_number(total_srps(@region_stats)) %> records)</span></p>
              <p>│   │   ├── <span class="text-amber-400">brussels/</span></p>
              <p>│   │   ├── <span class="text-cyan-400">flanders/</span></p>
              <p>│   │   └── <span class="text-purple-400">wallonia/</span></p>
              <p>│   └── <span class="text-purple-400">home/</span> <span class="text-slate-500">(<%= format_number(total_homes(@region_stats)) %> records)</span></p>
              <p>│       ├── <span class="text-amber-400">brussels/</span></p>
              <p>│       ├── <span class="text-cyan-400">flanders/</span></p>
              <p>│       └── <span class="text-purple-400">wallonia/</span></p>
              <p>├── <span class="text-emerald-400">counters/</span></p>
              <p>│   ├── srp_count</p>
              <p>│   └── home_count</p>
              <p>└── <span class="text-emerald-400">region_counters/</span></p>
              <p>    ├── brussels/</p>
              <p>    ├── flanders/</p>
              <p>    └── wallonia/</p>
            </div>
          </div>

          <!-- Region Counters -->
          <h3 class="text-lg font-semibold text-white mt-8 mb-4">Region Counters</h3>
          <div class="grid grid-cols-3 gap-4">
            <%= for {region, stats} <- @region_stats do %>
              <div class="bg-slate-800 rounded-xl border border-slate-700 p-4">
                <div class="flex items-center gap-2 mb-3">
                  <div class={"w-3 h-3 rounded-full " <> region_dot_color(region)}></div>
                  <span class="text-white font-medium capitalize"><%= region %></span>
                </div>
                <div class="space-y-2 font-mono text-sm">
                  <div class="flex justify-between">
                    <span class="text-slate-400">srps:</span>
                    <span class="text-cyan-400"><%= format_number(Map.get(stats, :srps, 0)) %></span>
                  </div>
                  <div class="flex justify-between">
                    <span class="text-slate-400">homes:</span>
                    <span class="text-purple-400"><%= format_number(Map.get(stats, :homes, 0)) %></span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp build_khepri_tree(region_stats, store_ready) do
    if store_ready do
      %{
        name: ":mri_demo_store",
        type: :root,
        children: [
          %{name: "mri", type: :namespace, children: [
            %{name: "srp", type: :type, count: total_srps(region_stats), children: region_children(region_stats, :srps)},
            %{name: "home", type: :type, count: total_homes(region_stats), children: region_children(region_stats, :homes)}
          ]},
          %{name: "counters", type: :namespace, children: []},
          %{name: "region_counters", type: :namespace, children: []}
        ]
      }
    else
      nil
    end
  end

  defp region_children(region_stats, key) do
    Enum.map(region_stats, fn {region, stats} ->
      %{name: region, type: :region, count: Map.get(stats, key, 0), children: []}
    end)
  end

  defp tree_node(assigns) do
    ~H"""
    <div style={"margin-left: #{@depth * 12}px"} class="text-sm">
      <div class="flex items-center gap-2 py-1 px-2 rounded hover:bg-slate-700/50 cursor-pointer">
        <%= if @node[:children] && length(@node[:children]) > 0 do %>
          <span class="text-slate-500 w-3">▼</span>
        <% else %>
          <span class="text-slate-600 w-3">•</span>
        <% end %>
        <span class={node_color(@node.type)}><%= @node.name %></span>
        <%= if @node[:count] do %>
          <span class="text-slate-500 text-xs ml-auto"><%= format_number(@node[:count]) %></span>
        <% end %>
      </div>
      <%= if @node[:children] do %>
        <%= for child <- @node[:children] do %>
          <.tree_node node={child} depth={@depth + 1} />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp node_color(:root), do: "text-slate-300"
  defp node_color(:namespace), do: "text-blue-400"
  defp node_color(:type), do: "text-cyan-400"
  defp node_color(:region), do: "text-amber-400"
  defp node_color(_), do: "text-slate-400"
end
