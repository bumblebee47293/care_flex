defmodule CareflexWeb.Schema.AppointmentTypes do
  @moduledoc """
  GraphQL types and operations for appointments.
  """

  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias CareflexWeb.Resolvers

  @desc "An appointment for care services"
  object :appointment do
    field :id, non_null(:id)
    field :patient_id, non_null(:id)
    field :care_service_type, non_null(:care_service_type)
    field :scheduled_at, non_null(:datetime)
    field :duration_minutes, non_null(:integer)
    field :status, non_null(:appointment_status)
    field :provider_id, :string
    field :provider_name, :string
    field :cancellation_reason, :string
    field :cancelled_at, :datetime
    field :no_show_risk_score, :integer
    field :notes, :string
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)

    # Associations
    field :patient, :patient, resolve: dataloader(CareflexCore)
    field :notifications, list_of(:notification), resolve: dataloader(CareflexCore)
  end

  @desc "Type of care service"
  enum :care_service_type do
    value :home_visit, description: "In-home care visit"
    value :telehealth, description: "Virtual telehealth appointment"
    value :transportation, description: "Transportation service"
    value :meal_delivery, description: "Meal delivery service"
    value :wellness_check, description: "Wellness check appointment"
  end

  @desc "Appointment status"
  enum :appointment_status do
    value :scheduled
    value :confirmed
    value :in_progress
    value :completed
    value :cancelled
    value :no_show
  end

  @desc "Input for scheduling an appointment"
  input_object :schedule_appointment_input do
    field :patient_id, non_null(:id)
    field :care_service_type, non_null(:care_service_type)
    field :scheduled_at, non_null(:datetime)
    field :duration_minutes, :integer
    field :provider_id, :string
    field :provider_name, :string
    field :notes, :string
  end

  @desc "Input for rescheduling an appointment"
  input_object :reschedule_appointment_input do
    field :scheduled_at, non_null(:datetime)
    field :notes, :string
  end

  @desc "Input for cancelling an appointment"
  input_object :cancel_appointment_input do
    field :cancellation_reason, non_null(:string)
  end

  object :appointment_queries do
    @desc "Get all appointments (with filters)"
    field :appointments, list_of(:appointment) do
      arg :patient_id, :id
      arg :status, :appointment_status
      arg :from_date, :datetime
      arg :to_date, :datetime
      arg :page, :integer, default_value: 1
      arg :page_size, :integer, default_value: 50
      resolve &Resolvers.Appointment.list_appointments/3
    end

    @desc "Get a single appointment by ID"
    field :appointment, :appointment do
      arg :id, non_null(:id)
      resolve &Resolvers.Appointment.get_appointment/3
    end

    @desc "Get upcoming appointments for a patient"
    field :upcoming_appointments, list_of(:appointment) do
      arg :patient_id, non_null(:id)
      arg :timezone, :string
      resolve &Resolvers.Appointment.get_upcoming_appointments/3
    end
  end

  object :appointment_mutations do
    @desc "Schedule a new appointment"
    field :schedule_appointment, :appointment do
      arg :input, non_null(:schedule_appointment_input)
      resolve &Resolvers.Appointment.schedule_appointment/3
    end

    @desc "Reschedule an existing appointment"
    field :reschedule_appointment, :appointment do
      arg :id, non_null(:id)
      arg :input, non_null(:reschedule_appointment_input)
      resolve &Resolvers.Appointment.reschedule_appointment/3
    end

    @desc "Cancel an appointment"
    field :cancel_appointment, :appointment do
      arg :id, non_null(:id)
      arg :input, non_null(:cancel_appointment_input)
      resolve &Resolvers.Appointment.cancel_appointment/3
    end

    @desc "Update appointment status"
    field :update_appointment_status, :appointment do
      arg :id, non_null(:id)
      arg :status, non_null(:appointment_status)
      resolve &Resolvers.Appointment.update_status/3
    end
  end

  object :appointment_subscriptions do
    @desc "Subscribe to appointment updates"
    field :appointment_updated, :appointment do
      arg :patient_id, :id

      config fn args, _info ->
        case args do
          %{patient_id: patient_id} ->
            {:ok, topic: "appointments:#{patient_id}"}
          _ ->
            {:ok, topic: "appointments:all"}
        end
      end

      trigger [:schedule_appointment, :reschedule_appointment, :cancel_appointment, :update_appointment_status],
        topic: fn
          %{patient_id: patient_id} -> ["appointments:#{patient_id}", "appointments:all"]
          _ -> ["appointments:all"]
        end
    end

    @desc "Subscribe to dashboard updates (for call center)"
    field :dashboard_update, :appointment do
      config fn _args, _info ->
        {:ok, topic: "dashboard:updates"}
      end
    end
  end
end
