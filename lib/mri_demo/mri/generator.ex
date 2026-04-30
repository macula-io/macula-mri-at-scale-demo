defmodule MriDemo.Mri.Generator do
  @moduledoc """
  Generates Proximus-like network topology at configurable scale.

  At 100% scale:
  - ~4,000 Street Relay Points (SRPs)
  - ~1,000,000 Home connections
  - Distributed across Brussels, Flanders, and Wallonia
  """

  alias MriDemo.Mri.Store

  @realm "be.proximus"

  @regions %{
    "brussels" => %{srps: 400, name: "Brussels"},
    "flanders" => %{srps: 2200, name: "Flanders"},
    "wallonia" => %{srps: 1400, name: "Wallonia"}
  }

  @homes_per_srp 250

  def regions, do: @regions

  @doc """
  Generate network at specified scale (0.0 to 1.0).

  Options:
  - progress_callback: fn(region, phase, current, total) -> :ok
  """
  def generate(scale, opts \\ []) when scale > 0 and scale <= 1.0 do
    callback = Keyword.get(opts, :progress_callback, fn _, _, _, _ -> :ok end)

    regions = for {region_id, config} <- @regions do
      srp_count = max(1, round(config.srps * scale))
      homes_per = max(1, round(@homes_per_srp * scale))

      {region_id, %{
        name: config.name,
        srp_count: srp_count,
        homes_per_srp: homes_per
      }}
    end

    # Generate each region
    Enum.each(regions, fn {region_id, config} ->
      generate_region(region_id, config, callback)
    end)

    :ok
  end

  defp generate_region(region_id, config, callback) do
    %{srp_count: srp_count, homes_per_srp: homes_per} = config

    # Generate SRPs
    callback.(region_id, :srps, 0, srp_count)

    Enum.each(1..srp_count, fn n ->
      srp_mri = make_srp_mri(region_id, n)
      metadata = %{
        type: :srp,
        region: region_id,
        capacity: 288,
        active_ports: :rand.uniform(288),
        status: :active
      }
      Store.register(srp_mri, metadata)

      # Report progress every 10 SRPs or at the end
      if rem(n, 10) == 0 or n == srp_count do
        callback.(region_id, :srps, n, srp_count)
      end
    end)

    # Generate homes for each SRP
    total_homes = srp_count * homes_per
    callback.(region_id, :homes, 0, total_homes)

    homes_done =
      Enum.reduce(1..srp_count, 0, fn srp_num, acc ->
        # Slight variation in homes per SRP
        variation = :rand.uniform(max(1, round(homes_per * 0.2))) - round(homes_per * 0.1)
        actual_homes = max(1, homes_per + variation)

        Enum.each(1..actual_homes, fn home_num ->
          home_mri = make_home_mri(region_id, srp_num, home_num)
          metadata = %{
            type: :home,
            region: region_id,
            srp_id: srp_num,
            connection_type: :fiber,
            bandwidth: Enum.random([100, 200, 400, 1000]),
            status: :active
          }
          Store.register(home_mri, metadata)
        end)

        new_acc = acc + actual_homes

        # Report progress every 500 homes or at the end
        if rem(new_acc, 500) < actual_homes or srp_num == srp_count do
          callback.(region_id, :homes, new_acc, total_homes)
        end

        new_acc
      end)

    callback.(region_id, :complete, homes_done, homes_done)
  end

  defp make_srp_mri(region, num) do
    srp_id = String.pad_leading("#{num}", 6, "0")
    "mri:srp:#{@realm}/#{region}/srp-#{srp_id}"
  end

  defp make_home_mri(region, srp_num, home_num) do
    srp_id = String.pad_leading("#{srp_num}", 6, "0")
    home_id = String.pad_leading("#{home_num}", 8, "0")
    "mri:home:#{@realm}/#{region}/srp-#{srp_id}/home-#{home_id}"
  end

  @doc """
  Get expected counts at a given scale.
  """
  def expected_counts(scale) do
    total_srps = Enum.reduce(@regions, 0, fn {_, c}, acc -> acc + round(c.srps * scale) end)
    homes_per = max(1, round(@homes_per_srp * scale))
    total_homes = total_srps * homes_per

    %{
      scale: scale,
      total_srps: total_srps,
      total_homes: total_homes,
      regions: Enum.map(@regions, fn {id, c} ->
        srps = round(c.srps * scale)
        {id, %{name: c.name, srps: srps, homes: srps * homes_per}}
      end) |> Enum.into(%{})
    }
  end
end
