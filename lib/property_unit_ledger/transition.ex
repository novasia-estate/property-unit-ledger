defmodule PropertyUnitLedger.Transition do
  @moduledoc false
  alias PropertyUnitLedger.{Event, Unit}

  def apply(nil, %Event{kind: :register} = e), do: {:ok, %Unit{id: e.unit_id, last_at: e.at}}
  def apply(nil, _), do: {:error, :unknown_unit}
  def apply(%Unit{} = u, %Event{} = e) do
    if DateTime.compare(e.at, u.last_at) == :lt do
      {:error, :out_of_order}
    else
      transition(u, e)
    end
  end

  defp transition(_, %Event{kind: :register}), do: {:error, :already_registered}
  defp transition(%Unit{status: :available} = u, %Event{kind: :reserve} = e),
    do: {:ok, %{u | status: :reserved, reservation_id: e.reservation_id, expires_at: e.expires_at, last_at: e.at}}
  defp transition(%Unit{status: :reserved} = u, %Event{kind: kind} = e) when kind in [:release, :expire] do
    cond do
      u.reservation_id != e.reservation_id -> {:error, :reservation_mismatch}
      kind == :expire and DateTime.compare(e.at, u.expires_at) == :lt -> {:error, :not_yet_expired}
      true -> {:ok, %{u | status: :available, reservation_id: nil, expires_at: nil, last_at: e.at}}
    end
  end
  defp transition(%Unit{status: :available} = u, %Event{kind: :sell} = e),
    do: {:ok, %{u | status: :sold, last_at: e.at}}
  defp transition(%Unit{status: :reserved} = u, %Event{kind: :sell} = e) do
    cond do
      e.reservation_id != u.reservation_id -> {:error, :reservation_mismatch}
      DateTime.compare(e.at, u.expires_at) != :lt -> {:error, :reservation_expired}
      true -> {:ok, %{u | status: :sold, reservation_id: nil, expires_at: nil, last_at: e.at}}
    end
  end
  defp transition(%Unit{status: :available} = u, %Event{kind: :withdraw} = e),
    do: {:ok, %{u | status: :withdrawn, last_at: e.at}}
  defp transition(_, _), do: {:error, :invalid_transition}
end
