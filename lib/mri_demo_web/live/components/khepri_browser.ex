defmodule MriDemoWeb.Components.KhepriBrowser do
  @moduledoc """
  Tree browser component for viewing Khepri data structure.
  """
  use Phoenix.Component

  alias MriDemo.Mri.Store

  attr :store_ready, :boolean, required: true
  attr :expanded_paths, :list, default: []
  attr :class, :string, default: ""

  def khepri_browser(assigns) do
    tree = if assigns.store_ready, do: fetch_tree_structure(), else: nil
    assigns = assign(assigns, :tree, tree)

    ~H"""
    <div class={["bg-slate-800/50 rounded-xl p-4 border border-slate-700 font-mono text-sm", @class]}>
      <h3 class="text-slate-300 font-semibold mb-3 flex items-center gap-2">
        <span class="text-lg">🌳</span> Khepri Store
      </h3>

      <%= if @store_ready do %>
        <div class="max-h-64 overflow-y-auto space-y-1">
          <%= if @tree do %>
            <.tree_node node={@tree} depth={0} />
          <% else %>
            <p class="text-slate-500 italic">Loading...</p>
          <% end %>
        </div>
      <% else %>
        <p class="text-slate-500 italic">Store not initialized</p>
      <% end %>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :depth, :integer, required: true

  defp tree_node(assigns) do
    ~H"""
    <div style={"margin-left: #{@depth * 16}px"}>
      <div class="flex items-center gap-1 py-0.5 hover:bg-slate-700/50 rounded px-1 cursor-pointer">
        <%= if @node[:children] && length(@node[:children]) > 0 do %>
          <span class="text-slate-500 w-4">▼</span>
        <% else %>
          <span class="text-slate-600 w-4">•</span>
        <% end %>

        <span class={node_color(@node[:type])}><%= @node[:name] %></span>

        <%= if @node[:count] do %>
          <span class="text-slate-500 text-xs ml-2">(<%= format_count(@node[:count]) %>)</span>
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
  defp node_color(:type), do: "text-cyan-400"
  defp node_color(:realm), do: "text-purple-400"
  defp node_color(:region), do: "text-amber-400"
  defp node_color(:srp), do: "text-emerald-400"
  defp node_color(_), do: "text-slate-400"

  defp format_count(n) when n >= 1000, do: "#{Float.round(n / 1000, 1)}K"
  defp format_count(n), do: "#{n}"

  defp fetch_tree_structure do
    try do
      stats = Store.get_stats()
      region_stats = Store.get_region_stats()

      %{
        name: ":mri_demo_store",
        type: :root,
        children: [
          %{
            name: "[:mri]",
            type: :root,
            children: [
              %{
                name: "[:srp]",
                type: :type,
                count: stats.srp_count,
                children: [
                  %{
                    name: "[be.proximus]",
                    type: :realm,
                    children: build_region_nodes(region_stats, :srps)
                  }
                ]
              },
              %{
                name: "[:home]",
                type: :type,
                count: stats.home_count,
                children: [
                  %{
                    name: "[be.proximus]",
                    type: :realm,
                    children: build_region_nodes(region_stats, :homes)
                  }
                ]
              }
            ]
          },
          %{
            name: "[:counters]",
            type: :root,
            children: []
          },
          %{
            name: "[:region_counters]",
            type: :root,
            children: []
          }
        ]
      }
    rescue
      _ -> nil
    end
  end

  defp build_region_nodes(region_stats, type_key) do
    Enum.map(region_stats, fn {region, stats} ->
      count = Map.get(stats, type_key, 0)
      %{
        name: "[#{region}]",
        type: :region,
        count: count,
        children: []
      }
    end)
    |> Enum.sort_by(& &1[:name])
  end
end
