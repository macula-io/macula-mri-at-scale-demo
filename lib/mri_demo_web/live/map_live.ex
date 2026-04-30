defmodule MriDemoWeb.MapLive do
  use MriDemoWeb, :live_view

  alias MriDemo.DemoServer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: DemoServer.subscribe()
    state = DemoServer.get_state()

    {:ok,
     socket
     |> assign(:region_stats, state.region_stats)
     |> assign(:status, state.status)
     |> assign(:scale, state.scale)}
  end

  @impl true
  def handle_info({:demo_state, state}, socket) do
    socket =
      socket
      |> assign(:region_stats, state.region_stats)
      |> assign(:status, state.status)
      |> assign(:scale, state.scale)

    # Push marker data to the map
    markers = build_markers(state.region_stats)
    socket = push_event(socket, "update-markers", %{markers: markers})

    {:noreply, socket}
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
          srp_idx = rem(:erlang.phash2({region, :home_srp, i}), max(srp_count, 1))
          srp = Enum.at(srp_markers, srp_idx) || %{lat: 50.5, lng: 4.5}
          {lat, lng} = jitter_point({srp.lat, srp.lng}, 0.008, {region, :home, i})
          %{type: "home", lat: lat, lng: lng, region: region}
        end

      srp_markers ++ home_markers
    end)
  end

  defp get_region_cities("flanders") do
    [
      {51.2194, 4.4025}, {51.0543, 3.7174}, {51.2093, 3.2247}, {50.8798, 4.7005},
      {51.0259, 4.4776}, {50.9369, 4.0367}, {50.8279, 3.2649}, {50.9307, 5.3378},
      {51.1565, 4.1434}, {50.9654, 5.5012}, {50.9446, 3.1257}, {51.0300, 3.5100},
      {51.1833, 4.9333}, {50.9281, 5.0958}, {51.0167, 3.1333}, {51.0989, 3.9894},
      {50.8503, 3.6167}, {51.1308, 4.3372}, {50.9833, 5.1833}, {51.2333, 4.8333},
    ]
  end

  defp get_region_cities("brussels") do
    [
      {50.8503, 4.3517}, {50.8667, 4.3833}, {50.8333, 4.3000}, {50.8278, 4.3778},
      {50.8214, 4.3989}, {50.8667, 4.3333}, {50.8500, 4.4167}, {50.8333, 4.4333},
      {50.8000, 4.3500}, {50.8167, 4.3167}, {50.8833, 4.3667}, {50.8667, 4.4167},
    ]
  end

  defp get_region_cities("wallonia") do
    [
      {50.6326, 5.5797}, {50.4108, 4.4446}, {50.4669, 4.8675}, {50.4542, 3.9523},
      {50.4795, 4.1854}, {50.6058, 3.3883}, {50.4136, 4.6108}, {50.5972, 5.8567},
      {50.4167, 4.0333}, {50.2500, 5.0000}, {49.6833, 5.8167}, {50.0833, 5.3667},
      {50.4875, 3.8108}, {50.4667, 4.2833}, {50.5500, 4.3500}, {50.3667, 4.8333},
    ]
  end

  defp get_region_cities(_), do: [{50.5, 4.5}]

  defp jitter_point({lat, lng}, radius, seed) do
    h = :erlang.phash2(seed)
    angle = rem(h, 360) * :math.pi() / 180
    dist = rem(div(h, 360), 1000) / 1000 * radius
    new_lat = lat + dist * :math.cos(angle)
    new_lng = lng + dist * :math.sin(angle) * 1.5
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
    <div class="min-h-screen bg-slate-900">
      <!-- Header -->
      <div class="bg-slate-800 border-b border-slate-700 px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-white">Belgium Network Map</h1>
            <p class="text-slate-400">Proximus MRI Infrastructure - OpenStreetMap View</p>
          </div>
          <div class="flex items-center gap-6">
            <div class="text-right">
              <div class="text-sm text-slate-400">SRPs</div>
              <div class="text-2xl font-bold text-cyan-400"><%= format_number(total_srps(@region_stats)) %></div>
            </div>
            <div class="text-right">
              <div class="text-sm text-slate-400">Homes</div>
              <div class="text-2xl font-bold text-purple-400"><%= format_number(total_homes(@region_stats)) %></div>
            </div>
            <a href="/" class="px-4 py-2 bg-slate-700 text-white rounded-lg hover:bg-slate-600">
              ← Back to Demo
            </a>
          </div>
        </div>
      </div>

      <!-- Map Container -->
      <div
        id="belgium-map"
        phx-hook="BelgiumMap"
        phx-update="ignore"
        class="w-full"
        style="height: calc(100vh - 80px);"
        data-initial-markers={Jason.encode!(build_markers(@region_stats))}
      >
      </div>

      <!-- Legend Overlay -->
      <div class="fixed bottom-6 left-6 bg-slate-800/95 backdrop-blur rounded-xl p-4 border border-slate-700 shadow-xl">
        <h3 class="text-white font-semibold mb-3">Legend</h3>
        <div class="space-y-2">
          <div class="flex items-center gap-3">
            <div class="w-4 h-4 rounded-full bg-cyan-400 shadow-lg shadow-cyan-400/50"></div>
            <span class="text-slate-300 text-sm">SRP Node</span>
          </div>
          <div class="flex items-center gap-3">
            <div class="w-2 h-2 rounded-full bg-purple-400 opacity-70"></div>
            <span class="text-slate-300 text-sm">Home Connection</span>
          </div>
        </div>
        <div class="mt-4 pt-3 border-t border-slate-700">
          <div class="grid grid-cols-3 gap-2 text-xs">
            <div class="flex items-center gap-1">
              <div class="w-2 h-2 rounded-full bg-cyan-400"></div>
              <span class="text-slate-400">Flanders</span>
            </div>
            <div class="flex items-center gap-1">
              <div class="w-2 h-2 rounded-full bg-amber-400"></div>
              <span class="text-slate-400">Brussels</span>
            </div>
            <div class="flex items-center gap-1">
              <div class="w-2 h-2 rounded-full bg-purple-400"></div>
              <span class="text-slate-400">Wallonia</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Status Overlay -->
      <%= if @status == :generating do %>
        <div class="fixed top-24 right-6 bg-emerald-500/90 backdrop-blur rounded-lg px-4 py-2 flex items-center gap-2 shadow-lg">
          <div class="w-3 h-3 bg-white rounded-full animate-pulse"></div>
          <span class="text-white font-medium">Generating Network...</span>
        </div>
      <% end %>
    </div>
    """
  end
end
