defmodule PropertyUnitLedger.Unit do
  @moduledoc "State of one inventory unit. Identifiers are opaque strings, never names of buyers."
  @enforce_keys [:id]
  defstruct [:id, :reservation_id, :expires_at, :last_at, status: :available]
end
