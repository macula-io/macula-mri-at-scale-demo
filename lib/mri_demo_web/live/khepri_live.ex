defmodule MriDemoWeb.KhepriLive do
  use MriDemoWeb, :live_view

  alias MriDemo.DemoServer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: DemoServer.subscribe()
    state = DemoServer.get_state()

    {:ok,
     socket
     |> assign(:store_ready, state.store_ready)
     |> assign(:region_stats, state.region_stats)
     |> assign(:expanded, MapSet.new(["/", "/mri"]))
     |> assign(:selected_path, nil)
     |> assign(:selected_data, nil)
     |> assign(:tree, build_tree(state))}
  end

  @impl true
  def handle_info({:demo_state, state}, socket) do
    {:noreply,
     socket
     |> assign(:store_ready, state.store_ready)
     |> assign(:region_stats, state.region_stats)
     |> assign(:tree, build_tree(state))}
  end

  @impl true
  def handle_event("toggle", %{"path" => path}, socket) do
    expanded = socket.assigns.expanded

    expanded =
      if MapSet.member?(expanded, path) do
        MapSet.delete(expanded, path)
      else
        MapSet.put(expanded, path)
      end

    {:noreply, assign(socket, :expanded, expanded)}
  end

  @impl true
  def handle_event("select", %{"path" => path}, socket) do
    data = fetch_path_data(path)
    {:noreply, socket |> assign(:selected_path, path) |> assign(:selected_data, data)}
  end

  defp build_tree(state) do
    if state.store_ready do
      %{
        name: ":mri_demo_store",
        path: "/",
        type: :root,
        children: [
          %{
            name: "mri",
            path: "/mri",
            type: :namespace,
            children: [
              %{
                name: "srp",
                path: "/mri/srp",
                type: :type,
                count: total_of(state.region_stats, :srps),
                children: build_region_children(state.region_stats, :srps, "/mri/srp")
              },
              %{
                name: "home",
                path: "/mri/home",
                type: :type,
                count: total_of(state.region_stats, :homes),
                children: build_region_children(state.region_stats, :homes, "/mri/home")
              }
            ]
          },
          %{
            name: "counters",
            path: "/counters",
            type: :namespace,
            children: [
              %{name: "srp_count", path: "/counters/srp_count", type: :counter, value: total_of(state.region_stats, :srps)},
              %{name: "home_count", path: "/counters/home_count", type: :counter, value: total_of(state.region_stats, :homes)}
            ]
          },
          %{
            name: "region_counters",
            path: "/region_counters",
            type: :namespace,
            children: Enum.map(state.region_stats, fn {region, stats} ->
              %{
                name: region,
                path: "/region_counters/#{region}",
                type: :region,
                children: [
                  %{name: "srps", path: "/region_counters/#{region}/srps", type: :counter, value: Map.get(stats, :srps, 0)},
                  %{name: "homes", path: "/region_counters/#{region}/homes", type: :counter, value: Map.get(stats, :homes, 0)}
                ]
              }
            end)
          }
        ]
      }
    else
      nil
    end
  end

  defp build_region_children(region_stats, type_key, base_path) do
    Enum.map(region_stats, fn {region, stats} ->
      count = Map.get(stats, type_key, 0)
      %{
        name: region,
        path: "#{base_path}/#{region}",
        type: :region,
        count: count,
        children: []
      }
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp total_of(stats, key) do
    Enum.reduce(stats, 0, fn {_, s}, acc -> acc + Map.get(s, key, 0) end)
  end

  defp fetch_path_data(path) do
    # Simulate fetching data for a path
    case path do
      "/counters/srp_count" -> %{type: :counter, value: "dynamic"}
      "/counters/home_count" -> %{type: :counter, value: "dynamic"}
      p when is_binary(p) -> %{type: :node, path: p}
    end
  end

  defp format_count(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 2)}M"
  defp format_count(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_count(n) when is_integer(n), do: "#{n}"
  defp format_count(_), do: "-"

  defp node_icon(:root), do: "🗄️"
  defp node_icon(:namespace), do: "📁"
  defp node_icon(:type), do: "📋"
  defp node_icon(:region), do: "🌍"
  defp node_icon(:counter), do: "🔢"
  defp node_icon(_), do: "📄"

  defp node_color(:root), do: "text-slate-300"
  defp node_color(:namespace), do: "text-blue-400"
  defp node_color(:type), do: "text-cyan-400"
  defp node_color(:region), do: "text-amber-400"
  defp node_color(:counter), do: "text-emerald-400"
  defp node_color(_), do: "text-slate-400"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900 flex">
      <!-- Sidebar Tree Browser -->
      <div class="w-96 bg-slate-800 border-r border-slate-700 flex flex-col">
        <div class="p-4 border-b border-slate-700">
          <h1 class="text-xl font-bold text-white flex items-center gap-2">
            <span>🌳</span> Khepri Store Browser
          </h1>
          <p class="text-sm text-slate-400 mt-1">Explore the distributed data structure</p>
        </div>

        <div class="flex-1 overflow-auto p-4">
          <%= if @store_ready && @tree do %>
            <.tree_node node={@tree} expanded={@expanded} selected={@selected_path} depth={0} />
          <% else %>
            <div class="text-center py-12">
              <div class="text-4xl mb-4">🔌</div>
              <p class="text-slate-400">Store not initialized</p>
              <a href="/" class="mt-4 inline-block px-4 py-2 bg-cyan-600 text-white rounded-lg hover:bg-cyan-500">
                Initialize Store →
              </a>
            </div>
          <% end %>
        </div>

        <div class="p-4 border-t border-slate-700">
          <a href="/" class="block w-full px-4 py-2 bg-slate-700 text-white text-center rounded-lg hover:bg-slate-600">
            ← Back to Demo
          </a>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 flex flex-col">
        <!-- Header -->
        <div class="bg-slate-800/50 border-b border-slate-700 px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold text-white">
                <%= if @selected_path, do: @selected_path, else: "Select a node to inspect" %>
              </h2>
            </div>
            <div class="flex items-center gap-4">
              <div class="px-3 py-1 bg-cyan-500/20 text-cyan-400 rounded-full text-sm">
                <%= format_count(total_of(@region_stats, :srps)) %> SRPs
              </div>
              <div class="px-3 py-1 bg-purple-500/20 text-purple-400 rounded-full text-sm">
                <%= format_count(total_of(@region_stats, :homes)) %> Homes
              </div>
            </div>
          </div>
        </div>

        <!-- Content -->
        <div class="flex-1 p-6 overflow-auto">
          <%= if @selected_path do %>
            <div class="bg-slate-800 rounded-xl border border-slate-700 overflow-hidden">
              <div class="px-4 py-3 bg-slate-700/50 border-b border-slate-700">
                <code class="text-cyan-400 font-mono"><%= @selected_path %></code>
              </div>
              <div class="p-4">
                <pre class="text-slate-300 font-mono text-sm whitespace-pre-wrap"><%= inspect(@selected_data, pretty: true) %></pre>
              </div>
            </div>

            <!-- Path Breakdown -->
            <div class="mt-6">
              <h3 class="text-white font-semibold mb-3">Path Components</h3>
              <div class="flex items-center gap-2 flex-wrap">
                <%= for {segment, idx} <- @selected_path |> String.split("/") |> Enum.reject(&(&1 == "")) |> Enum.with_index() do %>
                  <span class="px-3 py-1 bg-slate-800 text-slate-300 rounded font-mono text-sm border border-slate-700">
                    <%= segment %>
                  </span>
                  <%= if idx < length(String.split(@selected_path, "/")) - 2 do %>
                    <span class="text-slate-600">→</span>
                  <% end %>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="flex flex-col items-center justify-center h-full text-slate-500">
              <div class="text-6xl mb-6">🔍</div>
              <p class="text-xl">Select a node from the tree to inspect its data</p>
              <p class="mt-2 text-slate-600">Click on any item in the left sidebar</p>
            </div>
          <% end %>
        </div>

        <!-- Stats Footer -->
        <div class="bg-slate-800/50 border-t border-slate-700 px-6 py-4">
          <div class="grid grid-cols-3 gap-6">
            <%= for {region, stats} <- @region_stats do %>
              <div class="bg-slate-800 rounded-lg p-4 border border-slate-700">
                <div class="flex items-center gap-2 mb-2">
                  <div class={"w-3 h-3 rounded-full " <> region_color_class(region)}></div>
                  <span class="text-white font-medium capitalize"><%= region %></span>
                </div>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <span class="text-slate-400">SRPs</span>
                    <p class="text-cyan-400 font-bold"><%= format_count(Map.get(stats, :srps, 0)) %></p>
                  </div>
                  <div>
                    <span class="text-slate-400">Homes</span>
                    <p class="text-purple-400 font-bold"><%= format_count(Map.get(stats, :homes, 0)) %></p>
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

  defp region_color_class("flanders"), do: "bg-cyan-400"
  defp region_color_class("brussels"), do: "bg-amber-400"
  defp region_color_class("wallonia"), do: "bg-purple-400"
  defp region_color_class(_), do: "bg-slate-400"

  attr :node, :map, required: true
  attr :expanded, :any, required: true
  attr :selected, :string, default: nil
  attr :depth, :integer, required: true

  defp tree_node(assigns) do
    ~H"""
    <div style={"margin-left: #{@depth * 16}px"}>
      <div
        class={"flex items-center gap-2 py-1.5 px-2 rounded cursor-pointer hover:bg-slate-700/50 " <>
          if(@selected == @node.path, do: "bg-slate-700", else: "")}
        phx-click="select"
        phx-value-path={@node.path}
      >
        <%= if @node[:children] && length(@node[:children]) > 0 do %>
          <button
            phx-click="toggle"
            phx-value-path={@node.path}
            class="w-4 h-4 flex items-center justify-center text-slate-500 hover:text-white"
          >
            <%= if MapSet.member?(@expanded, @node.path), do: "▼", else: "▶" %>
          </button>
        <% else %>
          <span class="w-4 h-4 flex items-center justify-center text-slate-600">•</span>
        <% end %>

        <span class="text-base"><%= node_icon(@node.type) %></span>
        <span class={node_color(@node.type) <> " font-mono text-sm"}><%= @node.name %></span>

        <%= if @node[:count] do %>
          <span class="ml-auto text-slate-500 text-xs font-mono">
            <%= format_count(@node[:count]) %>
          </span>
        <% end %>

        <%= if @node[:value] do %>
          <span class="ml-auto text-emerald-400 text-xs font-mono">
            = <%= @node[:value] %>
          </span>
        <% end %>
      </div>

      <%= if MapSet.member?(@expanded, @node.path) && @node[:children] do %>
        <%= for child <- @node[:children] do %>
          <.tree_node node={child} expanded={@expanded} selected={@selected} depth={@depth + 1} />
        <% end %>
      <% end %>
    </div>
    """
  end
end
