defmodule PropertyUnitLedger.Event do
  @moduledoc "A validated, externally identified event. No atom creation from untrusted strings."
  @enforce_keys [:id, :unit_id, :kind, :at]
  defstruct [:id, :unit_id, :kind, :at, :reservation_id, :expires_at, :source]
  @kinds [:register, :reserve, :release, :expire, :sell, :withdraw]

  def validate(%__MODULE__{} = event) do
    cond do
      not text?(event.id) -> {:error, :invalid_event_id}
      not text?(event.unit_id) -> {:error, :invalid_unit_id}
      event.kind not in @kinds -> {:error, :invalid_event_kind}
      not utc?(event.at) -> {:error, :invalid_event_time}
      event.kind in [:reserve, :release, :expire] and not text?(event.reservation_id) -> {:error, :missing_reservation_id}
      event.kind == :reserve and not utc?(event.expires_at) -> {:error, :invalid_expiry}
      event.kind == :reserve and DateTime.compare(event.expires_at, event.at) != :gt -> {:error, :expiry_not_future}
      true -> :ok
    end
  end
  def validate(_), do: {:error, :invalid_event}
  defp text?(value), do: is_binary(value) and String.trim(value) != ""
  defp utc?(%DateTime{utc_offset: 0, std_offset: 0}), do: true
  defp utc?(_), do: false
end
