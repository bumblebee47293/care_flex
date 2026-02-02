defmodule CareflexWeb.Resolvers.Appointment do
  @moduledoc """
  GraphQL resolvers for appointment operations.
  """

  alias CareflexCore.Scheduling
  alias Absinthe.Subscription

  def list_appointments(_parent, args, _resolution) do
    opts = [
      page: Map.get(args, :page, 1),
      page_size: Map.get(args, :page_size, 50)
    ]

    opts = if args[:patient_id], do: Keyword.put(opts, :patient_id, args.patient_id), else: opts
    opts = if args[:status], do: Keyword.put(opts, :status, args.status), else: opts
    opts = if args[:from_date], do: Keyword.put(opts, :from_date, args.from_date), else: opts
    opts = if args[:to_date], do: Keyword.put(opts, :to_date, args.to_date), else: opts

    appointments = Scheduling.list_appointments(opts)
    {:ok, appointments}
  end

  def get_appointment(_parent, %{id: id}, _resolution) do
    case Scheduling.get_appointment!(id) do
      nil -> {:error, "Appointment not found"}
      appointment -> {:ok, appointment}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Appointment not found"}
  end

  def get_upcoming_appointments(_parent, %{patient_id: patient_id} = args, _resolution) do
    timezone = Map.get(args, :timezone, "America/New_York")
    appointments = Scheduling.get_upcoming_appointments(patient_id, timezone)
    {:ok, appointments}
  end

  def schedule_appointment(_parent, %{input: input}, resolution) do
    audit_context = build_audit_context(resolution, "schedule_appointment")

    case Scheduling.schedule_appointment(input, audit_context) do
      {:ok, appointment} ->
        # Trigger subscription
        Subscription.publish(
          resolution.context.pubsub,
          appointment,
          appointment_updated: "appointments:#{appointment.patient_id}"
        )
        Subscription.publish(
          resolution.context.pubsub,
          appointment,
          appointment_updated: "appointments:all"
        )
        {:ok, appointment}

      {:error, :scheduling_conflict} ->
        {:error, "Scheduling conflict: overlapping appointment exists"}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  end

  def reschedule_appointment(_parent, %{id: id, input: input}, resolution) do
    audit_context = build_audit_context(resolution, "reschedule_appointment")
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.reschedule_appointment(appointment, input, audit_context) do
      {:ok, updated_appointment} ->
        # Trigger subscription
        Subscription.publish(
          resolution.context.pubsub,
          updated_appointment,
          appointment_updated: "appointments:#{updated_appointment.patient_id}"
        )
        {:ok, updated_appointment}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Appointment not found"}
  end

  def cancel_appointment(_parent, %{id: id, input: input}, resolution) do
    audit_context = build_audit_context(resolution, "cancel_appointment")
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.cancel_appointment(appointment, input, audit_context) do
      {:ok, cancelled_appointment} ->
        # Trigger subscription
        Subscription.publish(
          resolution.context.pubsub,
          cancelled_appointment,
          appointment_updated: "appointments:#{cancelled_appointment.patient_id}"
        )
        {:ok, cancelled_appointment}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Appointment not found"}
  end

  def update_status(_parent, %{id: id, status: status}, resolution) do
    audit_context = build_audit_context(resolution, "update_appointment_status")
    appointment = Scheduling.get_appointment!(id)

    case Scheduling.update_appointment_status(appointment, status, audit_context) do
      {:ok, updated_appointment} ->
        # Trigger subscription
        Subscription.publish(
          resolution.context.pubsub,
          updated_appointment,
          appointment_updated: "appointments:#{updated_appointment.patient_id}"
        )
        {:ok, updated_appointment}

      {:error, changeset} ->
        {:error, format_errors(changeset)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Appointment not found"}
  end

  defp build_audit_context(resolution, action) do
    %{
      user_role: :admin,
      action: action,
      ip_address: get_in(resolution.context, [:ip_address]),
      user_agent: get_in(resolution.context, [:user_agent])
    }
  end

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
