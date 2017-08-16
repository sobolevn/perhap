defmodule Perhap.Events do

  @uuid_v1_regex    "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
  @time_order_regex "[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{12}"

  # Timestamps and unique integers
  @spec timestamp() :: integer
  def timestamp(), do: System.system_time(:microseconds)
  
  @spec unique_integer() :: integer
  def unique_integer(), do: System.unique_integer([:monotonic])

  # UUID v1
  @spec get_uuid_v1() :: String.t
  def get_uuid_v1() do
    { uuid, _state } = :uuid.get_v1(:uuid.new(self(), :erlang))
    :uuid.uuid_to_string(uuid)
  end

  @spec is_uuid_v1?(charlist() | binary()) :: true | false
  def is_uuid_v1?(nil), do: false
  def is_uuid_v1?(input) when is_list(input), do: is_uuid_v1?(to_string(input))
  def is_uuid_v1?(input) when is_binary(input) do
    try do
      :uuid.is_v1(:uuid.string_to_uuid(input))
    catch
      :exit, _ -> false
    end
  end

  @spec uuid_v1_to_time_order(charlist() | binary()) :: String.t
  def uuid_v1_to_time_order(uuid_v1) when is_list(uuid_v1) do
    uuid_v1_to_time_order(to_string(uuid_v1))
  end
  def uuid_v1_to_time_order(uuid_v1) when is_binary(uuid_v1) do
    [time_low, time_mid, time_high, node_hi, node_low] = String.split(uuid_v1, "-")
    time_high <> "-" <> time_mid <> "-" <> time_low <> "-" <> node_hi <> "-" <> node_low
  end

  @spec time_order_to_uuid_v1(charlist() | binary()) :: String.t
  def time_order_to_uuid_v1(time_order_uuid_v1) when is_list(time_order_uuid_v1) do
    time_order_to_uuid_v1(to_string(time_order_uuid_v1))
  end
  def time_order_to_uuid_v1(time_order_uuid_v1) when is_binary(time_order_uuid_v1) do
    [time_high, time_mid, time_low, node_hi, node_low] = String.split(time_order_uuid_v1, "-")
    time_low <> "-" <> time_mid <> "-" <> time_high <> "-" <> node_hi <> "-" <> node_low
  end

  @spec extract_uuid_v1_time(charlist() | binary()) :: integer()
  def extract_uuid_v1_time(input) when is_binary(input), do: extract_uuid_v1_time(to_charlist(input))
  def extract_uuid_v1_time(input) when is_list(input) do
    uuid = case is_time_order?(input) do
      true -> input |> time_order_to_uuid_v1
      _ -> input
    end
    uuid |> :uuid.string_to_uuid |> :uuid.get_v1_time
  end

  @spec is_time_order?(charlist() | binary()) :: true | false
  def is_time_order?(input) when is_list(input), do: is_time_order?(to_string(input))
  def is_time_order?(input) when is_binary(input) do
    Regex.match?(~r/#{@time_order_regex}/, input)
  end

  # UUID v4
  @spec get_uuid_v4() :: String.t
  def get_uuid_v4() do
    :uuid.get_v4() |> :uuid.uuid_to_string
  end

  @spec is_uuid_v4?(charlist()|binary()) :: true|false
  def is_uuid_v4?(nil), do: false
  def is_uuid_v4?(input) when is_list(input), do: is_uuid_v4?(to_string(input))
  def is_uuid_v4?(input) when is_binary(input) do
    try do
      :uuid.is_v4(:uuid.string_to_uuid(input))
    catch
      :exit, _ -> false
    end
  end

end