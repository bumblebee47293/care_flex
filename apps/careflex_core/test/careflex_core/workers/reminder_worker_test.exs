defmodule CareflexCore.Workers.ReminderWorkerTest do
  use CareflexCore.DataCase, async: true
  use Oban.Testing, repo: CareflexCore.Repo

  alias CareflexCore.Workers.ReminderWorker

  describe "perform/1" do
    test "sends reminder for scheduled appointment" do
      patient = insert(:patient)
      appointment = insert(:appointment, patient_id: patient.id, status: :scheduled)

      assert :ok = perform_job(ReminderWorker, %{
        "appointment_id" => appointment.id,
        "reminder_type" => "24_hour"
      })
    end

    test "skips reminder for cancelled appointment" do
      patient = insert(:patient)
      appointment = insert(:cancelled_appointment, patient_id: patient.id)

      assert {:ok, :skipped} = perform_job(ReminderWorker, %{
        "appointment_id" => appointment.id,
        "reminder_type" => "2_hour"
      })
    end

    test "respects patient communication preferences for SMS" do
      patient = insert(:patient, communication_preferences: %{"prefer_sms" => true})
      appointment = insert(:appointment, patient_id: patient.id)

      assert :ok = perform_job(ReminderWorker, %{
        "appointment_id" => appointment.id,
        "reminder_type" => "24_hour"
      })
    end

    test "uses voice for patients preferring voice calls" do
      patient = insert(:patient, communication_preferences: %{"prefer_voice" => true})
      appointment = insert(:appointment, patient_id: patient.id)

      assert :ok = perform_job(ReminderWorker, %{
        "appointment_id" => appointment.id,
        "reminder_type" => "2_hour"
      })
    end
  end
end
