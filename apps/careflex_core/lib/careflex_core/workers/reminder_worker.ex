defmodule CareflexCore.Workers.ReminderWorker do
  @moduledoc """
  Oban worker for sending appointment reminders.

  Sends SMS or voice reminders based on patient communication preferences.
  Scheduled at 24 hours and 2 hours before appointments.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  alias CareflexCore.{Repo, Scheduling, Notifications}
  alias CareflexCore.Scheduling.Appointment

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"appointment_id" => appointment_id, "reminder_type" => reminder_type}}) do
    appointment = Scheduling.get_appointment!(appointment_id)

    # Only send if appointment is still scheduled or confirmed
    if appointment.status in [:scheduled, :confirmed] do
      send_reminder(appointment, reminder_type)
    else
      {:ok, :skipped}
    end
  end

  defp send_reminder(appointment, reminder_type) do
    appointment = Repo.preload(appointment, :patient)
    patient = appointment.patient

    # Determine notification type from patient preferences
    notification_type = get_preferred_notification_type(patient)

    # Generate message content
    content = generate_reminder_message(appointment, reminder_type)

    # Send notification
    case Notifications.send_notification(%{
      patient_id: patient.id,
      appointment_id: appointment.id,
      notification_type: notification_type,
      template_name: "appointment_reminder_#{reminder_type}",
      content: content
    }) do
      {:ok, _notification} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_preferred_notification_type(patient) do
    preferences = patient.communication_preferences || %{}

    cond do
      Map.get(preferences, "prefer_voice") == true -> :voice
      Map.get(preferences, "prefer_sms") == true -> :sms
      true -> :sms  # Default to SMS
    end
  end

  defp generate_reminder_message(appointment, "24_hour") do
    """
    Reminder: You have a #{format_service_type(appointment.care_service_type)} appointment tomorrow at #{format_time(appointment.scheduled_at)}.

    To reschedule or cancel, please call us or use the patient portal.
    """
  end

  defp generate_reminder_message(appointment, "2_hour") do
    """
    Reminder: Your #{format_service_type(appointment.care_service_type)} appointment is in 2 hours at #{format_time(appointment.scheduled_at)}.

    We look forward to seeing you!
    """
  end

  defp format_service_type(service_type) do
    service_type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_time(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0..4)
  end
end
