defmodule Perhap.EventTest do
  use ExUnit.Case, async: true
  import PerhapTest.Helper, only: :functions

  test "timestamp returns system time in microseconds" do
    assert_in_delta(Perhap.Event.timestamp(), :erlang.system_time(:microsecond), 10)
  end

  test "unique_integer returns monotonically increasing integers" do
    unique_integers = for _n <- 1..10, do: Perhap.Event.unique_integer()
    assert unique_integers == Enum.sort(unique_integers |> Enum.dedup)
  end

  test "get_uuid_v1 returns valid uuid_v1" do
    assert :uuid.is_v1(Perhap.Event.get_uuid_v1() |> :uuid.string_to_uuid)
  end

  test "knows a uuid_v1 when it sees one" do
    assert Perhap.Event.is_uuid_v1?(make_v1())
  end

  test "flips the time so it can be sorted, and back again" do
    uuid = make_v1()
    [ulow, umid, uhigh, _, _] = String.split(uuid, "-")
    flipped = Perhap.Event.uuid_v1_to_time_order(uuid)
    [fhigh, fmid, flow, _, _] = String.split(flipped, "-")
    double_flipped = Perhap.Event.time_order_to_uuid_v1(flipped)
    refute uuid == flipped
    assert uuid == double_flipped
    assert {ulow, umid, uhigh} == {flow, fmid, fhigh}
  end

  test "extract datetime returns the time the event was created" do
    uuid_time = make_v1() |> Perhap.Event.extract_uuid_v1_time
    system_time = System.system_time(:microsecond)
    assert_in_delta(system_time, uuid_time, 100_000)
  end

  test "returns a valid uuid_v4" do
    assert :uuid.is_v4(Perhap.Event.get_uuid_v4() |> :uuid.string_to_uuid())
  end

  test "knows a valid uuid_v4 when it sees one" do
    assert Perhap.Event.is_uuid_v4?(make_v4())
  end

  test "invalidates an event" do
    assert Perhap.Event.validate(%{}) == {:invalid, "Invalid event struct"}
    assert Perhap.Event.validate( %Perhap.Event{:metadata => %{}}) == {:invalid, "Invalid event struct"}
    assert Perhap.Event.validate(%Perhap.Event{}) == {:invalid, "Invalid event_id"}
    assert Perhap.Event.validate(PerhapTest.Helper.make_random_event(%Perhap.Event.Metadata{:entity_id => "not a UUIDv4"})) == {:invalid, "Invalid entity_id"}
    event_with_context_not_set =
      PerhapTest.Helper.make_random_event()
      |> (fn x -> %Perhap.Event{x | metadata: %Perhap.Event.Metadata{x.metadata | context: nil}} end).()
    assert Perhap.Event.validate(event_with_context_not_set) == {:invalid, "Context not set for event"}
  end

  test "validates a valid event" do
    assert Perhap.Event.validate(PerhapTest.Helper.make_random_event()) == :ok
  end

  test "won't save an invalid event" do
    random_event = PerhapTest.Helper.make_random_event(%Perhap.Event.Metadata{:entity_id => ""})
    assert Perhap.Event.save_event(random_event) == {:invalid, "Invalid entity_id"}
  end

  test "saves and retrieves an event" do
    random_event = PerhapTest.Helper.make_random_event()
    assert Perhap.Event.save_event(random_event) == {:ok, random_event}
  end

  test "doesn't retrieve an event that doesn't exist" do
    assert Perhap.Event.retrieve_event(Perhap.Event.get_uuid_v1) == {:error, "Event not found"}
  end

  test "retrieves an event" do
    random_context = Enum.random([:k, :l, :m, :n, :o])
    rando = make_random_event(
      %Perhap.Event.Metadata{context: random_context} )
    Perhap.Event.save_event(rando)
    {:ok, result} = Perhap.Event.retrieve_event(rando.event_id)
    assert result.event_id == rando.event_id
  end

  test "retrieves events by context and entity ID" do
    random_context = Enum.random([:p, :q, :r, :s, :t])
    random_entity_id = Perhap.Event.get_uuid_v4()
    rando1 = make_random_event(
      %Perhap.Event.Metadata{context: random_context, entity_id: random_entity_id} )
    Perhap.Event.save_event(rando1)
    rando2 = make_random_event(
      %Perhap.Event.Metadata{context: random_context, entity_id: random_entity_id} )
    Perhap.Event.save_event(rando2)
    {:ok, [result1, result2]} = Perhap.Event.retrieve_events(random_context, entity_id: random_entity_id)
    assert result1.event_id == rando1.event_id
    assert result2.event_id == rando2.event_id
  end

  test "retrieves events by context" do
    random_context = Enum.random([:u, :v, :w, :x, :y])
    random_entity_id = Perhap.Event.get_uuid_v4()
    rando1 = make_random_event(
      %Perhap.Event.Metadata{context: random_context, entity_id: random_entity_id} )
    Perhap.Event.save_event(rando1)
    rando2 = make_random_event(
      %Perhap.Event.Metadata{context: random_context, entity_id: random_entity_id} )
    Perhap.Event.save_event(rando2)
    {:ok, [result1, result2]} = Perhap.Event.retrieve_events(random_context)
    assert result1.event_id == rando1.event_id
    assert result2.event_id == rando2.event_id
  end

  test "returns an empty list if events don't exist" do
    assert Perhap.Event.retrieve_events(:z) == {:ok, []}
    random_entity_id = Perhap.Event.get_uuid_v4()
    rando = make_random_event(
      %Perhap.Event.Metadata{context: :z, entity_id: random_entity_id} )
    Perhap.Event.save_event(rando)
    assert Perhap.Event.retrieve_events(:z, entity_id: Perhap.Event.get_uuid_v4) == {:ok, []}
    {:ok, [result1]} = Perhap.Event.retrieve_events(:z)
    assert result1.event_id == rando.event_id
    {:ok, [result2]} = Perhap.Event.retrieve_events(:z, entity_id: random_entity_id)
    assert result2.event_id == rando.event_id
  end

  test "retrieves events following an event for an entity" do
    assert Perhap.Event.retrieve_events(:aa) == {:ok, []}
    random_entity = Perhap.Event.get_uuid_v4
    random_event_ids = for _ <- 1..5, do: Perhap.Event.get_uuid_v1
    random_events = random_event_ids
                    |> Enum.map(fn(ev) ->
                      make_random_event(%Perhap.Event.Metadata{context: :aa, event_id: ev, entity_id: random_entity})
                    end)
    random_events |> Enum.each(fn(event) -> Perhap.Event.save_event(event) end)
    [ _ev1 | [ _ev2 | _ ] ] = random_event_ids |> Enum.reverse
    #first_event = Perhap.Event.retrieve_events(:aa, entity_id: random_entity, after: ev2)
  end

  test "retrieves events filtered by an event_type" do
  end

  defp make_v1() do
    {uuid, _} = :uuid.get_v1(:uuid.new(self()))
    uuid |> :uuid.uuid_to_string |> to_string()
  end

  defp make_v4() do
    :uuid.get_v4() |> :uuid.uuid_to_string |> to_string()
  end

end
