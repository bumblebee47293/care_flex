defmodule CareflexCore.Notifications.SMSProvider do
  @moduledoc """
  Mock SMS provider (Twilio-style).

  In production, this would integrate with Twilio, AWS SNS, or similar.
  Simulates SMS delivery with realistic delays and failure scenarios.
  """

  require Logger
  alias CareflexCore.Repo
  alias CareflexCore.Notifications.Notification

  @doc """
  Sends an SMS notification.
  """
  def send(%Notification{} = notification) do
    Logger.info("Sending SMS to patient #{notification.patient_id}")

    # Simulate API call
    Process.sleep(Enum.random(200..600))

    # Simulate 95% success rate
    if :rand.uniform(100) <= 95 do
      external_id = "SMS-#{:rand.uniform(1_000_000)}"

      notification
      |> Notification.sent_changeset(external_id)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          # Simulate delivery confirmation after a delay
          schedule_delivery_confirmation(updated)
          {:ok, updated}

        error ->
          error
      end
    else
      Logger.error("SMS delivery failed for notification #{notification.id}")

      notification
      |> Notification.failed_changeset("Provider API error")
      |> Repo.update()
    end
  end

  defp schedule_delivery_confirmation(notification) do
    # In production, this would be a webhook callback
    # For demo, we'll just mark it as delivered after a short delay
    Task.start(fn ->
      Process.sleep(Enum.random(1000..3000))

      notification
      |> Notification.delivered_changeset()
      |> Repo.update()
    end)
  end
end
