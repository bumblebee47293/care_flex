defmodule CareflexCore.Factory do
  @moduledoc """
  ExMachina factory for generating test data.

  Provides factories for all core schemas with realistic test data.
  """

  use ExMachina.Ecto, repo: CareflexCore.Repo

  alias CareflexCore.Care.Patient
  alias CareflexCore.Scheduling.Appointment
  alias CareflexCore.Benefits.Benefit
  alias CareflexCore.Audit.AuditLog
  alias CareflexCore.Notifications.Notification
  alias CareflexCore.Auth.User

  def patient_factory do
    %Patient{
      external_id: sequence(:external_id, &"PAT-#{&1}"),
      first_name: "John",
      last_name: "Doe",
      email: sequence(:email, &"patient#{&1}@example.com"),
      phone: "+1-555-0100",
      date_of_birth: ~D[1980-01-15],
      timezone: "America/New_York",
      status: :active,
      communication_preferences: %{
        "prefer_sms" => true,
        "prefer_voice" => false,
        "prefer_email" => true
      },
      accessibility_needs: %{
        "wheelchair_accessible" => false,
        "hearing_assistance" => false
      }
    }
  end

  def appointment_factory do
    %Appointment{
      patient: build(:patient),
      care_service_type: :home_visit,
      scheduled_at: DateTime.utc_now() |> DateTime.add(24, :hour),
      duration_minutes: 60,
      status: :scheduled,
      provider_id: "PROV-123",
      provider_name: "Dr. Smith",
      no_show_risk_score: 25,
      notes: "Regular checkup"
    }
  end

  def benefit_factory do
    today = Date.utc_today()

    %Benefit{
      patient: build(:patient),
      benefit_type: :transportation,
      total_allocated: Decimal.new("200.00"),
      used_amount: Decimal.new("0.00"),
      status: :active,
      period_start: Date.beginning_of_month(today),
      period_end: Date.end_of_month(today),
      external_plan_id: sequence(:plan_id, &"PLAN-#{&1}")
    }
  end

  def audit_log_factory do
    %AuditLog{
      user_id: sequence(:user_id, & &1),
      user_role: :admin,
      action: "create_patient",
      resource_type: "Patient",
      resource_id: sequence(:resource_id, & &1),
      changes: %{
        "first_name" => "John",
        "last_name" => "Doe"
      },
      metadata: %{
        "source" => "api"
      },
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    }
  end

  def notification_factory do
    %Notification{
      patient: build(:patient),
      notification_type: :sms,
      status: :pending,
      template_name: "appointment_reminder_24h",
      content: "You have an appointment tomorrow at 2:00 PM"
    }
  end

  # Helper factories for specific scenarios

  def confirmed_appointment_factory do
    build(:appointment, status: :confirmed)
  end

  def cancelled_appointment_factory do
    build(:appointment,
      status: :cancelled,
      cancellation_reason: "Patient requested cancellation",
      cancelled_at: DateTime.utc_now()
    )
  end

  def high_risk_appointment_factory do
    build(:appointment, no_show_risk_score: 85)
  end

  def depleted_benefit_factory do
    build(:benefit,
      total_allocated: Decimal.new("100.00"),
      used_amount: Decimal.new("100.00"),
      status: :depleted
    )
  end

  def expired_benefit_factory do
    past_date = Date.utc_today() |> Date.add(-30)

    build(:benefit,
      period_start: Date.add(past_date, -30),
      period_end: past_date,
      status: :expired
    )
  end

  def sent_notification_factory do
    build(:notification,
      status: :sent,
      sent_at: DateTime.utc_now(),
      external_provider_id: "MSG-123"
    )
  end

  def delivered_notification_factory do
    now = DateTime.utc_now()

    build(:notification,
      status: :delivered,
      sent_at: DateTime.add(now, -60, :second),
      delivered_at: now,
      external_provider_id: "MSG-123"
    )
  end

  def user_factory do
    %User{
      email: sequence(:user_email, &"user#{&1}@example.com"),
      password: "SecurePassword123!",
      first_name: "Test",
      last_name: "User",
      phone: "+1-555-0199",
      role: :patient,
      status: :active,
      failed_login_attempts: 0
    }
  end

  # Role-specific user factories
  def patient_user_factory do
    build(:user, role: :patient)
  end

  def agent_user_factory do
    build(:user,
      role: :agent,
      first_name: "Agent",
      last_name: "Smith"
    )
  end

  def admin_user_factory do
    build(:user,
      role: :admin,
      first_name: "Admin",
      last_name: "User"
    )
  end

  def locked_user_factory do
    build(:user,
      status: :locked,
      failed_login_attempts: 5,
      locked_at: DateTime.utc_now()
    )
  end
end
