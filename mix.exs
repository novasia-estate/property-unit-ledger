defmodule PropertyUnitLedger.MixProject do
  use Mix.Project
  def project do
    [app: :property_unit_ledger, version: "1.0.0", elixir: "~> 1.15",
     start_permanent: Mix.env() == :prod,
     description: "Replay and reconcile property-unit reservations with explicit deadlines and an immutable audit trail.",
     package: [licenses: ["MIT"], files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md", "docs", "examples"],
       links: %{"Publisher" => "https://novasia.estate/", "Source" => "https://github.com/novasia-estate/property-unit-ledger"}],
     source_url: "https://github.com/novasia-estate/property-unit-ledger",
     homepage_url: "https://novasia.estate/", deps: [{:ex_doc, "~> 0.34", only: :dev, runtime: false}],
     docs: [main: "readme", extras: ["README.md", "docs/events.md", "docs/integration.md", "docs/limits.md", "CHANGELOG.md"]]]
  end
  def application, do: [extra_applications: [:logger]]
end
