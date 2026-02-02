defmodule CareflexCore.Workers.NoShowPredictor do
  @moduledoc """
  Oban worker for calculating no-show risk scores.

  Runs daily via cron to update risk scores for upcoming appointments.
  Uses statistical analysis of patient history.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 2

  import Ecto.Query
  alias CareflexCore.{Repo, Scheduling}
  alias CareflexCore.Scheduling.Appointment

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Get all upcoming appointments in the next 7 days
    upcoming_appointments = get_upcoming_appointments()

    # Calculate and update risk scores
    results =
      Enum.map(upcoming_appointments, fn appointment ->
        update_risk_score(appointment)
      end)

    successful = Enum.count(results, &match?({:ok, _}, &1))
    failed = Enum.count(results, &match?({:error, _}, &1))

    {:ok, %{processed: length(results), successful: successful, failed: failed}}
  end

  defp get_upcoming_appointments do
    now = DateTime.utc_now()
    seven_days_from_now = DateTime.add(now, 7, :day)

    Appointment
    |> where([a], a.scheduled_at >= ^now)
    |> where([a], a.scheduled_at <= ^seven_days_from_now)
    |> where([a], a.status in [:scheduled, :confirmed])
    |> where([a], is_nil(a.deleted_at))
    |> Repo.all()
  end

  defp update_risk_score(appointment) do
    risk_score = Scheduling.calculate_no_show_risk(appointment)
    Scheduling.update_risk_score(appointment, risk_score)
  end
end
