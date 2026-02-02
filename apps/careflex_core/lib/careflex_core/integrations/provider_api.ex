defmodule CareflexCore.Integrations.ProviderAPI do
  @moduledoc """
  Mock client for external care provider availability API.

  In production, this would integrate with provider scheduling systems.
  Demonstrates retry logic and error handling patterns.
  """

  require Logger

  @doc """
  Fetches available appointment slots from provider.
  """
  def get_available_slots(provider_id, date) do
    Process.sleep(Enum.random(100..400))

    if :rand.uniform(100) <= 8 do
      Logger.warning("Provider API call failed for provider #{provider_id}")
      {:error, :service_unavailable}
    else
      {:ok, generate_mock_slots(provider_id, date)}
    end
  end

  @doc """
  Reserves a specific time slot with the provider.
  """
  def reserve_slot(provider_id, datetime) do
    Process.sleep(Enum.random(150..300))

    if :rand.uniform(100) <= 5 do
      {:error, :slot_no_longer_available}
    else
      {:ok, %{
        reservation_id: "RES-#{:rand.uniform(100000)}",
        provider_id: provider_id,
        scheduled_at: datetime,
        status: :confirmed
      }}
    end
  end

  @doc """
  Cancels a reservation with the provider.
  """
  def cancel_reservation(reservation_id) do
    Process.sleep(Enum.random(100..250))

    {:ok, %{
      reservation_id: reservation_id,
      status: :cancelled,
      cancelled_at: DateTime.utc_now()
    }}
  end

  defp generate_mock_slots(provider_id, date) do
    # Generate slots from 9 AM to 5 PM
    Enum.map(9..16, fn hour ->
      datetime = DateTime.new!(date, Time.new!(hour, 0, 0), "America/New_York")

      %{
        provider_id: provider_id,
        start_time: datetime,
        duration_minutes: 60,
        available: :rand.uniform(100) > 30  # 70% availability
      }
    end)
    |> Enum.filter(& &1.available)
  end
end
