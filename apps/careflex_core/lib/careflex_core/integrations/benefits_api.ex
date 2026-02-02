defmodule CareflexCore.Integrations.BenefitsAPI do
  @moduledoc """
  Mock client for external insurance benefits API.

  In production, this would integrate with real insurance provider APIs.
  Simulates network delays, failures, and circuit breaker patterns.
  """

  require Logger

  @doc """
  Fetches patient benefits from external API.

  Returns mock data for demonstration purposes.
  """
  def get_patient_benefits(patient_id) do
    # Simulate API call delay
    Process.sleep(Enum.random(100..500))

    # Simulate occasional failures (10% failure rate)
    if :rand.uniform(100) <= 10 do
      Logger.warning("Benefits API call failed for patient #{patient_id}")
      {:error, :api_unavailable}
    else
      {:ok, generate_mock_benefits(patient_id)}
    end
  end

  @doc """
  Checks eligibility for a specific benefit.
  """
  def check_eligibility(patient_id, benefit_type) do
    Process.sleep(Enum.random(50..200))

    if :rand.uniform(100) <= 5 do
      {:error, :timeout}
    else
      {:ok, %{
        eligible: true,
        benefit_type: benefit_type,
        remaining_balance: Decimal.new("500.00")
      }}
    end
  end

  defp generate_mock_benefits(patient_id) do
    today = Date.utc_today()
    period_start = Date.beginning_of_month(today)
    period_end = Date.end_of_month(today)

    [
      %{
        plan_id: "EXT-#{patient_id}-TRANS",
        benefit_type: :transportation,
        total_allocated: Decimal.new("200.00"),
        used_amount: Decimal.new("50.00"),
        period_start: period_start,
        period_end: period_end,
        status: :active
      },
      %{
        plan_id: "EXT-#{patient_id}-MEALS",
        benefit_type: :meals,
        total_allocated: Decimal.new("300.00"),
        used_amount: Decimal.new("120.00"),
        period_start: period_start,
        period_end: period_end,
        status: :active
      },
      %{
        plan_id: "EXT-#{patient_id}-FITNESS",
        benefit_type: :fitness,
        total_allocated: Decimal.new("150.00"),
        used_amount: Decimal.new("0.00"),
        period_start: period_start,
        period_end: period_end,
        status: :active
      }
    ]
  end
end
