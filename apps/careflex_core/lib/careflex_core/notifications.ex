defmodule CareflexCore.Notifications do
  @moduledoc """
  The Notifications context - manages patient communications.

  Handles multi-channel notifications (SMS, Voice, Email) with:
  - Patient communication preferences
  - Template-based messaging
  - Delivery tracking
  - Audit logging
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Notifications.{Notification, SMSProvider, VoiceProvider}

  @doc """
  Sends a notification to a patient.
  """
  def send_notification(attrs) do
    with {:ok, notification} <- create_notification(attrs),
         {:ok, updated_notification} <- dispatch_notification(notification) do
      {:ok, updated_notification}
    end
  end

  defp create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  defp dispatch_notification(notification) do
    notification = Repo.preload(notification, :patient)

    case notification.notification_type do
      :sms -> SMSProvider.send(notification)
      :voice -> VoiceProvider.send(notification)
      :email -> {:ok, notification}  # Email not implemented in this demo
    end
  end

  @doc """
  Gets notification history for a patient.
  """
  def get_patient_notifications(patient_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    Notification
    |> where([n], n.patient_id == ^patient_id)
    |> order_by([n], desc: n.inserted_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> Repo.all()
  end

  @doc """
  Gets notification delivery statistics.
  """
  def get_delivery_stats(from_date, to_date) do
    Notification
    |> where([n], n.inserted_at >= ^from_date)
    |> where([n], n.inserted_at <= ^to_date)
    |> group_by([n], [n.notification_type, n.status])
    |> select([n], %{
      notification_type: n.notification_type,
      status: n.status,
      count: count(n.id)
    })
    |> Repo.all()
  end
end
