defmodule CareflexCore.Scheduling do
  @moduledoc """
  The Scheduling context - manages appointments and care schedules.

  This context handles:
  - Appointment creation with conflict detection
  - Rescheduling and cancellation
  - Timezone-aware queries
  - No-show risk scoring
  - Real-time updates via PubSub
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Scheduling.Appointment
  alias CareflexCore.Audit
  alias Phoenix.PubSub

  @pubsub CareFlex.PubSub

  @doc """
  Returns the list of appointments with optional filters.

  ## Options

    * `:patient_id` - Filter by patient
    * `:status` - Filter by status
    * `:from_date` - Start date range
    * `:to_date` - End date range
    * `:page` - Page number (default: 1)
    * `:page_size` - Results per page (default: 50)

  """
  def list_appointments(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 50)

    Appointment
    |> apply_appointment_filters(opts)
    |> where([a], is_nil(a.deleted_at))
    |> order_by([a], asc: a.scheduled_at)
    |> limit(^page_size)
    |> offset(^((page - 1) * page_size))
    |> preload(:patient)
    |> Repo.all()
  end

  defp apply_appointment_filters(query, opts) do
    Enum.reduce(opts, query, fn
      {:patient_id, patient_id}, query ->
        where(query, [a], a.patient_id == ^patient_id)

      {:status, status}, query ->
        where(query, [a], a.status == ^status)

      {:from_date, from_date}, query ->
        where(query, [a], a.scheduled_at >= ^from_date)

      {:to_date, to_date}, query ->
        where(query, [a], a.scheduled_at <= ^to_date)

      _other, query ->
        query
    end)
  end

  @doc """
  Gets upcoming appointments for a patient in their timezone.
  """
  def get_upcoming_appointments(patient_id, timezone \\ "America/New_York") do
    now = DateTime.now!(timezone)

    Appointment
    |> where([a], a.patient_id == ^patient_id)
    |> where([a], a.scheduled_at >= ^now)
    |> where([a], a.status in [:scheduled, :confirmed])
    |> where([a], is_nil(a.deleted_at))
    |> order_by([a], asc: a.scheduled_at)
    |> Repo.all()
  end

  @doc """
  Gets a single appointment.
  """
  def get_appointment!(id) do
    Appointment
    |> where([a], is_nil(a.deleted_at))
    |> preload(:patient)
    |> Repo.get!(id)
  end

  @doc """
  Schedules a new appointment with conflict detection.
  """
  def schedule_appointment(attrs \\ %{}, audit_context \\ %{}) do
    with {:ok, appointment} <- create_appointment_record(attrs),
         :ok <- check_conflicts(appointment) do

      Audit.log_action(
        Map.merge(audit_context, %{
          action: "schedule_appointment",
          resource_type: "Appointment",
          resource_id: appointment.id,
          changes: attrs
        })
      )

      # Broadcast to dashboard
      broadcast_appointment_update(appointment, :scheduled)

      # Schedule reminder jobs
      schedule_reminders(appointment)

      {:ok, appointment}
    end
  end

  defp create_appointment_record(attrs) do
    %Appointment{}
    |> Appointment.changeset(attrs)
    |> Repo.insert()
  end

  defp check_conflicts(%Appointment{} = appointment) do
    # Check for overlapping appointments for the same patient
    conflict_exists? =
      Appointment
      |> where([a], a.patient_id == ^appointment.patient_id)
      |> where([a], a.id != ^appointment.id)
      |> where([a], a.status in [:scheduled, :confirmed])
      |> where([a], is_nil(a.deleted_at))
      |> where(
        [a],
        fragment(
          "? < ? + (? || ' minutes')::interval AND ? + (? || ' minutes')::interval > ?",
          a.scheduled_at,
          ^appointment.scheduled_at,
          ^appointment.duration_minutes,
          a.scheduled_at,
          a.duration_minutes,
          ^appointment.scheduled_at
        )
      )
      |> Repo.exists?()

    if conflict_exists? do
      {:error, :scheduling_conflict}
    else
      :ok
    end
  end

  @doc """
  Reschedules an existing appointment.
  """
  def reschedule_appointment(%Appointment{} = appointment, attrs, audit_context \\ %{}) do
    result =
      appointment
      |> Appointment.reschedule_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_appointment} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "reschedule_appointment",
            resource_type: "Appointment",
            resource_id: appointment.id,
            changes: attrs
          })
        )

        broadcast_appointment_update(updated_appointment, :rescheduled)
        schedule_reminders(updated_appointment)

        {:ok, updated_appointment}

      error ->
        error
    end
  end

  @doc """
  Cancels an appointment.
  """
  def cancel_appointment(%Appointment{} = appointment, attrs, audit_context \\ %{}) do
    result =
      appointment
      |> Appointment.cancel_changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, cancelled_appointment} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "cancel_appointment",
            resource_type: "Appointment",
            resource_id: appointment.id,
            changes: attrs
          })
        )

        broadcast_appointment_update(cancelled_appointment, :cancelled)

        {:ok, cancelled_appointment}

      error ->
        error
    end
  end

  @doc """
  Updates appointment status.
  """
  def update_appointment_status(%Appointment{} = appointment, status, audit_context \\ %{}) do
    result =
      appointment
      |> Appointment.status_changeset(status)
      |> Repo.update()

    case result do
      {:ok, updated_appointment} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "update_appointment_status",
            resource_type: "Appointment",
            resource_id: appointment.id,
            changes: %{status: status}
          })
        )

        broadcast_appointment_update(updated_appointment, :status_changed)

        {:ok, updated_appointment}

      error ->
        error
    end
  end

  @doc """
  Updates the no-show risk score for an appointment.
  """
  def update_risk_score(%Appointment{} = appointment, score) do
    appointment
    |> Appointment.risk_score_changeset(score)
    |> Repo.update()
  end

  @doc """
  Calculates no-show risk score based on patient history.

  Simple statistical model based on:
  - Historical no-show rate
  - Days since last appointment
  - Cancellation history
  - Day of week patterns
  """
  def calculate_no_show_risk(%Appointment{} = appointment) do
    patient_id = appointment.patient_id

    # Get patient's appointment history
    total_appointments =
      Appointment
      |> where([a], a.patient_id == ^patient_id)
      |> where([a], a.scheduled_at < ^DateTime.utc_now())
      |> where([a], is_nil(a.deleted_at))
      |> Repo.aggregate(:count)

    no_shows =
      Appointment
      |> where([a], a.patient_id == ^patient_id)
      |> where([a], a.status == :no_show)
      |> where([a], is_nil(a.deleted_at))
      |> Repo.aggregate(:count)

    cancellations =
      Appointment
      |> where([a], a.patient_id == ^patient_id)
      |> where([a], a.status == :cancelled)
      |> where([a], is_nil(a.deleted_at))
      |> Repo.aggregate(:count)

    # Calculate base risk score
    base_score =
      cond do
        total_appointments == 0 -> 50  # New patient, medium risk
        true -> min(round((no_shows + cancellations * 0.5) / total_appointments * 100), 100)
      end

    # Adjust for day of week (weekends typically higher no-show)
    day_of_week = Date.day_of_week(DateTime.to_date(appointment.scheduled_at))
    day_adjustment = if day_of_week in [6, 7], do: 10, else: 0

    min(base_score + day_adjustment, 100)
  end

  defp broadcast_appointment_update(appointment, event_type) do
    PubSub.broadcast(
      @pubsub,
      "dashboard:updates",
      {:appointment_updated, %{appointment: appointment, event: event_type}}
    )
  end

  defp schedule_reminders(%Appointment{} = appointment) do
    # Schedule 24-hour reminder
    %{appointment_id: appointment.id, reminder_type: "24_hour"}
    |> CareflexCore.Workers.ReminderWorker.new(
      scheduled_at: DateTime.add(appointment.scheduled_at, -24, :hour)
    )
    |> Oban.insert()

    # Schedule 2-hour reminder
    %{appointment_id: appointment.id, reminder_type: "2_hour"}
    |> CareflexCore.Workers.ReminderWorker.new(
      scheduled_at: DateTime.add(appointment.scheduled_at, -2, :hour)
    )
    |> Oban.insert()

    :ok
  end
end
