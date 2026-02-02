defmodule CareflexCore.NotificationsTest do
  use CareflexCore.DataCase, async: true

  alias CareflexCore.Notifications
  alias CareflexCore.Notifications.Notification

  describe "send_notification/3" do
    test "sends SMS notification" do
      patient = insert(:patient, communication_preferences: %{"prefer_sms" => true})

      attrs = %{
        patient_id: patient.id,
        notification_type: :sms,
        template_name: "appointment_reminder_24h",
        content: "Your appointment is tomorrow at 2:00 PM"
      }

      assert {:ok, %Notification{} = notification} = Notifications.send_notification(attrs, :sms, %{})
      assert notification.status == :sent
      assert notification.notification_type == :sms
    end

    test "sends voice notification" do
      patient = insert(:patient, communication_preferences: %{"prefer_voice" => true})

      attrs = %{
        patient_id: patient.id,
        notification_type: :voice,
        template_name: "appointment_reminder_2h",
        content: "Your appointment is in 2 hours"
      }

      assert {:ok, %Notification{} = notification} = Notifications.send_notification(attrs, :voice, %{})
      assert notification.status == :sent
      assert notification.notification_type == :voice
    end

    test "tracks delivery status" do
      patient = insert(:patient)

      attrs = %{
        patient_id: patient.id,
        notification_type: :sms,
        template_name: "test",
        content: "Test message"
      }

      {:ok, notification} = Notifications.send_notification(attrs, :sms, %{})

      assert notification.sent_at != nil
      assert notification.external_provider_id != nil
    end
  end

  describe "get_patient_notifications/1" do
    test "returns all notifications for patient" do
      patient = insert(:patient)

      insert(:notification, patient_id: patient.id, notification_type: :sms)
      insert(:notification, patient_id: patient.id, notification_type: :voice)

      # Another patient's notification
      insert(:notification)

      notifications = Notifications.get_patient_notifications(patient.id)

      assert length(notifications) == 2
    end
  end

  describe "get_delivery_stats/1" do
    test "calculates delivery statistics" do
      patient = insert(:patient)

      insert(:sent_notification, patient_id: patient.id)
      insert(:delivered_notification, patient_id: patient.id)
      insert(:notification, patient_id: patient.id, status: :failed)

      stats = Notifications.get_delivery_stats(patient.id)

      assert stats.total == 3
      assert stats.sent >= 1
      assert stats.delivered >= 1
      assert stats.failed >= 1
    end
  end
end
