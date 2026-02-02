defmodule CareflexWeb.Schema.NotificationTypes do
  @moduledoc """
  GraphQL types for notifications.
  """

  use Absinthe.Schema.Notation

  @desc "A notification sent to a patient"
  object :notification do
    field :id, non_null(:id)
    field :patient_id, non_null(:id)
    field :appointment_id, :id
    field :notification_type, non_null(:notification_type)
    field :status, non_null(:notification_status)
    field :template_name, non_null(:string)
    field :content, non_null(:string)
    field :sent_at, :datetime
    field :delivered_at, :datetime
    field :failed_at, :datetime
    field :failure_reason, :string
    field :inserted_at, non_null(:datetime)
  end

  @desc "Type of notification"
  enum :notification_type do
    value :sms
    value :voice
    value :email
  end

  @desc "Notification delivery status"
  enum :notification_status do
    value :pending
    value :sent
    value :delivered
    value :failed
  end
end
