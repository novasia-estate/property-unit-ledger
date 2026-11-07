defmodule PropertyUnitLedger do
  @moduledoc """
  Pure event replay for available/reserved/sold/withdrawn property inventory.

  Replays input order; never guesses the ordering of conflicting source updates.
  Exact duplicate event IDs are idempotent; different payloads with the same ID
  are rejected. Expiration requires an explicit event, not the machine clock.
  This is an integration component, not a legal sales registry or database lock.
  """
  alias PropertyUnitLedger.{Event, Transition}
  defstruct units: %{}, seen: %{}, journal: []

  @doc "Apply a validated event without mutating the prior ledger."
  def apply_event(%__MODULE__{} = ledger, event) do
    with :ok <- Event.validate(event) do
      case Map.fetch(ledger.seen, event.id) do
        {:ok, ^event} -> {:ok, ledger}
        {:ok, _} -> {:error, :event_id_conflict}
        :error ->
          with {:ok, unit} <- Transition.apply(Map.get(ledger.units, event.unit_id), event) do
            {:ok, %{ledger | units: Map.put(ledger.units, event.unit_id, unit),
              seen: Map.put(ledger.seen, event.id, event), journal: [event | ledger.journal]}}
          end
      end
    end
  end

  @doc "Replay in input order; return all rejections with zero-based input indices."
  def replay(events, ledger \\ %__MODULE__{}) do
    {state, errors} = events |> Enum.with_index() |> Enum.reduce({ledger, []}, fn {event, index}, {state, errors} ->
      case apply_event(state, event) do
        {:ok, next} -> {next, errors}
        {:error, reason} -> {state, [%{index: index, reason: reason} | errors]}
      end
    end)
    %{ledger: state, rejected: Enum.reverse(errors)}
  end

  @doc """
  Replay as an all-or-nothing import, keeping the original ledger if any event is rejected.

  Returns the same ordered rejection details as `replay/2`, plus `:committed?`.
  Valid events are simulated in input order to discover subsequent errors, but a
  rejected batch exposes no partial ledger or journal. Exact duplicate events
  retain their existing idempotency behavior. This is an in-memory operation;
  persistence still needs the caller's transaction or version check.
  """
  def replay_atomic(events, ledger \\ %__MODULE__{}) do
    result = replay(events, ledger)
    case result.rejected do
      [] -> Map.put(result, :committed?, true)
      errors -> %{ledger: ledger, rejected: errors, committed?: false}
    end
  end

  @doc "Accepted events in their original processing order."
  def history(%__MODULE__{} = ledger), do: Enum.reverse(ledger.journal)

  @doc "Expired reservations at a caller-supplied UTC instant, without changing state."
  def due(%__MODULE__{} = ledger, %DateTime{utc_offset: 0, std_offset: 0} = as_of) do
    ledger.units |> Map.values() |> Enum.filter(fn unit ->
      unit.status == :reserved and DateTime.compare(unit.expires_at, as_of) != :gt
    end) |> Enum.sort_by(& &1.id)
  end
end
