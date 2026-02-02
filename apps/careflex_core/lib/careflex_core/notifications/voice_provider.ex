defmodule CareflexCore.Notifications.VoiceProvider do
  @moduledoc """
  Mock voice call provider (Twilio-style).

  In production, this would integrate with Twilio Voice API.
  Simulates voice call delivery with text-to-speech.
  """

  require Logger
  alias CareflexCore.Repo
  alias CareflexCore.Notifications.Notification

  @doc """
  Initiates a voice call notification.
  """
  def send(%Notification{} = notification) do
    Logger.info("Initiating voice call to patient #{notification.patient_id}")

    # Simulate API call
    Process.sleep(Enum.random(300..800))

    # Simulate 90% success rate (voice has slightly lower success than SMS)
    if :rand.uniform(100) <= 90 do
      external_id = "VOICE-#{:rand.uniform(1_000_000)}"

      notification
      |> Notification.sent_changeset(external_id)
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          # Simulate call completion
          schedule_call_completion(updated)
          {:ok, updated}

        error ->
          error
      end
    else
      Logger.error("Voice call failed for notification #{notification.id}")

      notification
      |> Notification.failed_changeset("No answer or provider error")
      |> Repo.update()
    end
  end

  defp schedule_call_completion(notification) do
    Task.start(fn ->
      # Simulate call duration
      Process.sleep(Enum.random(5000..15000))

      notification
      |> Notification.delivered_changeset()
      |> Repo.update()
    end)
  end
end
