defmodule MriDemoWeb.Components.BelgiumMap do
  @moduledoc """
  SVG Belgium map with accurate geographic boundaries.
  Coordinates derived from OpenStreetMap/Natural Earth data.
  """
  use Phoenix.Component

  # Region bounds for dot placement {min_x, max_x, min_y, max_y}
  @region_bounds %{
    "brussels" => {240, 265, 148, 175},
    "flanders" => {40, 425, 45, 185},
    "wallonia" => {75, 455, 175, 410}
  }

  # Accurate Belgium country outline
  defp belgium_outline do
    "M 41.8,117.8 L 48.0,113.0 L 84.0,91.5 L 136.3,66.9 L 190.1,59.0 L 236.8,65.9 L 267.7,58.2 L 306.5,56.6 L 328.9,46.2 L 353.6,80.3 L 382.3,82.7 L 410.7,123.1 L 419.7,135.4 L 439.7,179.5 L 441.4,222.4 L 454.5,290.6 L 437.8,285.5 L 418.5,319.5 L 416.1,324.1 L 410.9,330.5 L 410.5,338.2 L 417.1,342.3 L 424.4,343.3 L 425.3,350.4 L 418.4,360.5 L 416.3,396.0 L 383.4,404.9 L 371.8,385.3 L 358.4,374.2 L 309.7,354.4 L 308.8,322.7 L 286.7,316.7 L 272.4,323.1 L 226.8,321.1 L 212.9,311.7 L 174.4,305.1 L 162.9,229.1 L 125.9,219.2 L 111.6,174.1 L 76.2,183.8 L 39.3,118.1 L 41.8,117.8 Z"
  end

  # Flanders - Northern Belgium with linguistic boundary
  defp flanders_path do
    "M 41.8,117.8 L 48.0,113.0 L 84.0,91.5 L 136.3,66.9 L 190.1,59.0 L 236.8,65.9 L 267.7,58.2 L 306.5,56.6 L 328.9,46.2 L 353.6,80.3 L 382.3,82.7 L 410.7,123.1 L 419.7,135.4 L 425.4,178.1 L 371.2,178.1 L 330.8,180.5 L 304.2,177.7 L 261.5,174.1 L 238.5,173.2 L 209.6,175.0 L 163.5,183.2 L 125.9,182.9 L 76.2,183.8 L 39.3,118.1 L 41.8,117.8 Z"
  end

  # Brussels Capital Region - enclave
  defp brussels_path do
    "M 241.9,171.2 L 245.4,168.6 L 248.8,165.0 L 252.3,161.4 L 255.8,157.7 L 259.2,154.1 L 261.5,150.5 L 260.4,149.5 L 256.9,151.4 L 252.3,155.0 L 248.8,158.6 L 245.4,162.3 L 243.1,166.8 L 241.9,171.2 Z"
  end

  # Wallonia - Southern Belgium
  defp wallonia_path do
    "M 76.2,183.8 L 125.9,182.9 L 163.5,183.2 L 209.6,175.0 L 238.5,173.2 L 261.5,174.1 L 304.2,177.7 L 330.8,180.5 L 371.2,178.1 L 425.4,178.1 L 439.7,179.5 L 441.4,222.4 L 454.5,290.6 L 437.8,285.5 L 418.5,319.5 L 416.1,324.1 L 410.9,330.5 L 410.5,338.2 L 417.1,342.3 L 424.4,343.3 L 425.3,350.4 L 418.4,360.5 L 416.3,396.0 L 383.4,404.9 L 371.8,385.3 L 358.4,374.2 L 309.7,354.4 L 308.8,322.7 L 286.7,316.7 L 272.4,323.1 L 226.8,321.1 L 212.9,311.7 L 174.4,305.1 L 162.9,229.1 L 125.9,219.2 L 111.6,174.1 L 76.2,183.8 Z"
  end

  attr :region_stats, :map, required: true
  attr :status, :atom, required: true
  attr :class, :string, default: ""

  def belgium_map(assigns) do
    dots = generate_dots(assigns.region_stats)
    assigns =
      assigns
      |> assign(:dots, dots)
      |> assign(:belgium_outline, belgium_outline())
      |> assign(:flanders_path, flanders_path())
      |> assign(:brussels_path, brussels_path())
      |> assign(:wallonia_path, wallonia_path())

    ~H"""
    <div class={["relative flex items-center justify-center", @class]}>
      <svg viewBox="0 0 500 450" class="w-full h-full max-w-4xl" preserveAspectRatio="xMidYMid meet" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="flandersGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#22d3ee" stop-opacity="0.9" />
            <stop offset="100%" stop-color="#0891b2" stop-opacity="0.7" />
          </linearGradient>
          <linearGradient id="brusselsGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#fbbf24" stop-opacity="1" />
            <stop offset="100%" stop-color="#f59e0b" stop-opacity="0.8" />
          </linearGradient>
          <linearGradient id="walloniaGrad" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" stop-color="#a855f7" stop-opacity="0.9" />
            <stop offset="100%" stop-color="#7c3aed" stop-opacity="0.7" />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="2" result="blur"/>
            <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
          <filter id="bigGlow">
            <feGaussianBlur stdDeviation="5" result="blur"/>
            <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
          <filter id="shadow">
            <feDropShadow dx="2" dy="3" stdDeviation="3" flood-opacity="0.4"/>
          </filter>
        </defs>

        <!-- Background -->
        <rect width="500" height="450" fill="#0f172a"/>
        <pattern id="grid" width="50" height="50" patternUnits="userSpaceOnUse">
          <path d="M 50 0 L 0 0 0 50" fill="none" stroke="#1e293b" stroke-width="0.5"/>
        </pattern>
        <rect width="500" height="450" fill="url(#grid)" opacity="0.4"/>

        <!-- Country glow outline -->
        <path d={@belgium_outline} fill="none" stroke="#3b82f6" stroke-width="8" opacity="0.2" filter="url(#bigGlow)"/>

        <!-- Wallonia (bottom layer) -->
        <path d={@wallonia_path} fill="url(#walloniaGrad)" stroke="#a855f7" stroke-width="2" filter="url(#shadow)"/>

        <!-- Flanders -->
        <path d={@flanders_path} fill="url(#flandersGrad)" stroke="#22d3ee" stroke-width="2" filter="url(#shadow)"/>

        <!-- Brussels (top layer - small enclave) -->
        <path d={@brussels_path} fill="url(#brusselsGrad)" stroke="#fbbf24" stroke-width="2.5" filter="url(#shadow)"/>

        <!-- Home connections -->
        <%= for %{type: :home, x: x, y: y, region: region} <- @dots do %>
          <circle cx={x} cy={y} r="1.2" fill={home_color(region)} opacity="0.5"/>
        <% end %>

        <!-- SRP nodes -->
        <%= for %{type: :srp, x: x, y: y, region: region} <- @dots do %>
          <circle cx={x} cy={y} r="3.5" fill={srp_color(region)} filter="url(#glow)"/>
        <% end %>

        <!-- Region labels -->
        <g font-family="system-ui, -apple-system, sans-serif">
          <text x="220" y="120" text-anchor="middle" fill="#22d3ee" font-size="18" font-weight="bold" filter="url(#glow)">
            FLANDERS
          </text>
          <text x="252" y="165" text-anchor="middle" fill="#fbbf24" font-size="10" font-weight="bold">
            BRUSSELS
          </text>
          <text x="300" y="290" text-anchor="middle" fill="#c084fc" font-size="18" font-weight="bold" filter="url(#glow)">
            WALLONIA
          </text>
        </g>

        <!-- Stats panel -->
        <g transform="translate(12, 12)">
          <rect width="130" height="85" fill="#1e293b" rx="8" opacity="0.95" filter="url(#shadow)"/>
          <text x="14" y="24" fill="#94a3b8" font-size="11" font-family="system-ui">Network Status</text>
          <line x1="14" y1="34" x2="116" y2="34" stroke="#334155" stroke-width="1"/>
          <text x="14" y="55" fill="#22d3ee" font-size="20" font-weight="bold" font-family="system-ui">
            <%= format_count(total_srps(@region_stats)) %>
          </text>
          <text x="80" y="55" fill="#94a3b8" font-size="12" font-family="system-ui">SRPs</text>
          <text x="14" y="77" fill="#c084fc" font-size="20" font-weight="bold" font-family="system-ui">
            <%= format_count(total_homes(@region_stats)) %>
          </text>
          <text x="80" y="77" fill="#94a3b8" font-size="12" font-family="system-ui">Homes</text>
        </g>

        <!-- Legend -->
        <g transform="translate(358, 12)">
          <rect width="130" height="70" fill="#1e293b" rx="8" opacity="0.95" filter="url(#shadow)"/>
          <circle cx="20" cy="26" r="5" fill="#22d3ee" filter="url(#glow)"/>
          <text x="35" y="30" fill="#e2e8f0" font-size="12" font-family="system-ui">SRP Node</text>
          <circle cx="20" cy="50" r="3" fill="#67e8f9" opacity="0.7"/>
          <text x="35" y="54" fill="#e2e8f0" font-size="12" font-family="system-ui">Home Connection</text>
        </g>

        <!-- Generation indicator -->
        <%= if @status == :generating do %>
          <g transform="translate(12, 400)">
            <rect width="150" height="28" fill="#1e293b" rx="6" opacity="0.95"/>
            <circle cx="18" cy="14" r="5" fill="#22c55e">
              <animate attributeName="r" values="5;7;5" dur="1s" repeatCount="indefinite"/>
              <animate attributeName="opacity" values="1;0.5;1" dur="1s" repeatCount="indefinite"/>
            </circle>
            <text x="32" y="19" fill="#22c55e" font-size="12" font-weight="bold" font-family="system-ui">
              GENERATING...
            </text>
          </g>
        <% end %>
      </svg>
    </div>
    """
  end

  defp srp_color("brussels"), do: "#fbbf24"
  defp srp_color("flanders"), do: "#22d3ee"
  defp srp_color("wallonia"), do: "#c084fc"
  defp srp_color(_), do: "#94a3b8"

  defp home_color("brussels"), do: "#fde68a"
  defp home_color("flanders"), do: "#a5f3fc"
  defp home_color("wallonia"), do: "#e9d5ff"
  defp home_color(_), do: "#e2e8f0"

  defp format_count(n) when n >= 1_000_000, do: "#{Float.round(n / 1_000_000, 2)}M"
  defp format_count(n) when n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_count(n), do: "#{n}"

  defp total_srps(stats), do: Enum.reduce(stats, 0, fn {_, s}, acc -> acc + Map.get(s, :srps, 0) end)
  defp total_homes(stats), do: Enum.reduce(stats, 0, fn {_, s}, acc -> acc + Map.get(s, :homes, 0) end)

  defp generate_dots(region_stats) do
    Enum.flat_map(region_stats, fn {region, stats} ->
      srps = min(Map.get(stats, :srps, 0), 150)
      homes = min(div(Map.get(stats, :homes, 0), 80), 500)

      srp_dots = for i <- 1..srps, do: %{type: :srp, region: region} |> Map.merge(pos(region, i))
      home_dots = for i <- 1..homes, do: %{type: :home, region: region} |> Map.merge(pos(region, i + 99999))

      srp_dots ++ home_dots
    end)
  end

  defp pos(region, idx) do
    {x1, x2, y1, y2} = Map.get(@region_bounds, region, {50, 450, 50, 400})
    h = :erlang.phash2({region, idx})
    %{
      x: Float.round(x1 + rem(h, 10000) / 10000 * (x2 - x1) * 0.9 + (x2 - x1) * 0.05, 1),
      y: Float.round(y1 + rem(div(h, 10000), 10000) / 10000 * (y2 - y1) * 0.9 + (y2 - y1) * 0.05, 1)
    }
  end
end
