defmodule MriDemo.Mri.Store do
  @moduledoc """
  Khepri-based MRI storage for the demo.

  MRIs are stored in a tree structure:
    [mri, type, realm, segment1, segment2, ...]

  We also maintain simple list indexes for fast queries without wildcards.
  """

  require Logger

  @store_name :mri_demo_store
  @data_dir "/tmp/mri_demo_khepri"

  ## Lifecycle

  @spec start() :: {:ok, atom()} | {:error, term()}
  def start do
    try do
      # Ensure Ra and Khepri are started
      {:ok, _} = Application.ensure_all_started(:ra)
      {:ok, _} = Application.ensure_all_started(:khepri)

      # Clean previous data
      File.rm_rf!(@data_dir)
      File.mkdir_p!(@data_dir)

      # Configure Ra system
      ra_config = %{
        name: @store_name,
        data_dir: String.to_charlist(@data_dir),
        wal_data_dir: String.to_charlist(@data_dir),
        names: :ra_system.derive_names(@store_name)
      }

      case :ra_system.start(ra_config) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      # Start Khepri store
      {:ok, _} = :khepri.start(@store_name, @store_name)
      :ok = :khepri.fence(@store_name, 10_000)

      # Initialize counters
      :khepri.put(@store_name, [:counters], %{srp: 0, home: 0})
      :khepri.put(@store_name, [:region_counters], %{
        "brussels" => %{srps: 0, homes: 0},
        "flanders" => %{srps: 0, homes: 0},
        "wallonia" => %{srps: 0, homes: 0}
      })

      Logger.info("MRI Store started: #{@store_name}")
      {:ok, @store_name}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  def stop do
    :khepri.stop(@store_name)
    :ra_system.stop(@store_name)
    File.rm_rf!(@data_dir)
    :ok
  end

  def store_name, do: @store_name

  ## Registration

  def register(mri, metadata) when is_binary(mri) do
    path = mri_to_path(mri)
    type = get_type_from_mri(mri)
    realm = get_realm_from_mri(mri)
    region = get_region_from_mri(mri)

    full_metadata = Map.merge(metadata, %{
      mri: mri,
      type: type,
      realm: realm,
      registered_at: System.system_time(:millisecond)
    })

    case :khepri.put(@store_name, path, full_metadata) do
      :ok ->
        # Update counters
        increment_counter(type, region)
        :ok
      {:error, _} = err -> err
    end
  end

  def lookup(mri) when is_binary(mri) do
    path = mri_to_path(mri)
    case :khepri.get(@store_name, path) do
      {:ok, metadata} -> {:ok, metadata}
      {:error, {:khepri, :node_not_found, _}} -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  def exists?(mri) when is_binary(mri) do
    path = mri_to_path(mri)
    :khepri.exists(@store_name, path)
  end

  def delete(mri) when is_binary(mri) do
    path = mri_to_path(mri)
    :khepri.delete(@store_name, path)
  end

  ## Bulk Operations

  def import(entries) when is_list(entries) do
    Enum.each(entries, fn {mri, metadata} ->
      register(mri, metadata)
    end)
    :ok
  end

  ## Queries (using counters for stats)

  def count_by_type(type, _realm) when is_atom(type) do
    case :khepri.get(@store_name, [:counters]) do
      {:ok, counters} -> Map.get(counters, type, 0)
      _ -> 0
    end
  end

  ## Stats

  def get_stats do
    case :khepri.get(@store_name, [:counters]) do
      {:ok, counters} ->
        srp_count = Map.get(counters, :srp, 0)
        home_count = Map.get(counters, :home, 0)
        %{
          srp_count: srp_count,
          home_count: home_count,
          total_mris: srp_count + home_count
        }
      _ ->
        %{srp_count: 0, home_count: 0, total_mris: 0}
    end
  end

  def get_region_stats do
    case :khepri.get(@store_name, [:region_counters]) do
      {:ok, region_counters} -> region_counters
      _ -> %{}
    end
  end

  ## Internal

  defp mri_to_path(mri) do
    case String.split(mri, ":") do
      ["mri", type_str, rest] ->
        type = String.to_atom(type_str)
        segments = String.split(rest, "/")
        [realm | path_segments] = segments
        [:mri, type, realm | path_segments]
      _ ->
        [:mri, :unknown, mri]
    end
  end

  defp get_type_from_mri(mri) do
    case String.split(mri, ":") do
      ["mri", type_str, _] -> String.to_atom(type_str)
      _ -> :unknown
    end
  end

  defp get_realm_from_mri(mri) do
    case String.split(mri, ":") do
      ["mri", _, rest] ->
        [realm | _] = String.split(rest, "/")
        realm
      _ -> "unknown"
    end
  end

  defp get_region_from_mri(mri) do
    case String.split(mri, ":") do
      ["mri", _, rest] ->
        segments = String.split(rest, "/")
        case segments do
          [_realm, region | _] -> region
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp increment_counter(type, region) do
    # Update global counter
    case :khepri.get(@store_name, [:counters]) do
      {:ok, counters} ->
        new_count = Map.get(counters, type, 0) + 1
        :khepri.put(@store_name, [:counters], Map.put(counters, type, new_count))
      _ -> :ok
    end

    # Update region counter
    case :khepri.get(@store_name, [:region_counters]) do
      {:ok, region_counters} ->
        region_stats = Map.get(region_counters, region, %{srps: 0, homes: 0})
        key = if type == :srp, do: :srps, else: :homes
        new_stats = Map.update(region_stats, key, 1, &(&1 + 1))
        :khepri.put(@store_name, [:region_counters], Map.put(region_counters, region, new_stats))
      _ -> :ok
    end
  end
end
