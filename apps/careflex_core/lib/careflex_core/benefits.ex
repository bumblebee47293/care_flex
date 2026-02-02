defmodule CareflexCore.Benefits do
  @moduledoc """
  The Benefits context - manages patient benefits and eligibility.

  This context handles:
  - Benefits allocation and tracking
  - Usage recording with decimal precision
  - Eligibility checking
  - External benefits API synchronization
  """

  import Ecto.Query, warn: false
  alias CareflexCore.Repo
  alias CareflexCore.Benefits.Benefit
  alias CareflexCore.Audit

  @doc """
  Returns all benefits for a patient.
  """
  def get_patient_benefits(patient_id) do
    Benefit
    |> where([b], b.patient_id == ^patient_id)
    |> where([b], is_nil(b.deleted_at))
    |> order_by([b], desc: b.period_start)
    |> Repo.all()
  end

  @doc """
  Gets active benefits for a patient within the current period.
  """
  def get_active_benefits(patient_id) do
    today = Date.utc_today()

    Benefit
    |> where([b], b.patient_id == ^patient_id)
    |> where([b], b.status == :active)
    |> where([b], b.period_start <= ^today)
    |> where([b], b.period_end >= ^today)
    |> where([b], is_nil(b.deleted_at))
    |> Repo.all()
  end

  @doc """
  Gets a specific benefit by ID.
  """
  def get_benefit!(id) do
    Benefit
    |> where([b], is_nil(b.deleted_at))
    |> Repo.get!(id)
  end

  @doc """
  Creates a benefit allocation.
  """
  def create_benefit(attrs \\ %{}, audit_context \\ %{}) do
    result =
      %Benefit{}
      |> Benefit.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, benefit} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "create_benefit",
            resource_type: "Benefit",
            resource_id: benefit.id,
            changes: attrs
          })
        )
        {:ok, benefit}

      error ->
        error
    end
  end

  @doc """
  Checks if a patient is eligible for a specific benefit type and amount.

  Returns:
    - `{:ok, benefit}` if eligible with sufficient balance
    - `{:error, :insufficient_balance}` if balance too low
    - `{:error, :no_active_benefit}` if no active benefit found
    - `{:error, :benefit_expired}` if benefit period has ended
  """
  def check_eligibility(patient_id, benefit_type, amount) do
    today = Date.utc_today()

    case Benefit
         |> where([b], b.patient_id == ^patient_id)
         |> where([b], b.benefit_type == ^benefit_type)
         |> where([b], b.status == :active)
         |> where([b], b.period_start <= ^today)
         |> where([b], b.period_end >= ^today)
         |> where([b], is_nil(b.deleted_at))
         |> Repo.one() do
      nil ->
        {:error, :no_active_benefit}

      benefit ->
        remaining = Benefit.remaining_balance(benefit)
        requested = Decimal.new(to_string(amount))

        if Decimal.compare(remaining, requested) in [:gt, :eq] do
          {:ok, benefit}
        else
          {:error, :insufficient_balance}
        end
    end
  end

  @doc """
  Records benefit usage.
  """
  def record_usage(benefit_id, amount, audit_context \\ %{}) do
    benefit = get_benefit!(benefit_id)

    result =
      benefit
      |> Benefit.usage_changeset(amount)
      |> Repo.update()

    case result do
      {:ok, updated_benefit} ->
        Audit.log_action(
          Map.merge(audit_context, %{
            action: "record_benefit_usage",
            resource_type: "Benefit",
            resource_id: benefit.id,
            changes: %{amount_used: amount}
          })
        )
        {:ok, updated_benefit}

      error ->
        error
    end
  end

  @doc """
  Synchronizes benefit data from external system.
  """
  def sync_external_benefits(patient_id) do
    # This would call the external benefits API
    # For now, we'll simulate the sync
    case CareflexCore.Integrations.BenefitsAPI.get_patient_benefits(patient_id) do
      {:ok, external_benefits} ->
        sync_results =
          Enum.map(external_benefits, fn external_benefit ->
            sync_single_benefit(patient_id, external_benefit)
          end)

        {:ok, sync_results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp sync_single_benefit(patient_id, external_data) do
    case Benefit
         |> where([b], b.patient_id == ^patient_id)
         |> where([b], b.external_plan_id == ^external_data.plan_id)
         |> where([b], is_nil(b.deleted_at))
         |> Repo.one() do
      nil ->
        # Create new benefit
        create_benefit(%{
          patient_id: patient_id,
          benefit_type: external_data.benefit_type,
          total_allocated: external_data.total_allocated,
          used_amount: external_data.used_amount,
          period_start: external_data.period_start,
          period_end: external_data.period_end,
          external_plan_id: external_data.plan_id,
          status: external_data.status
        })

      benefit ->
        # Update existing benefit
        benefit
        |> Benefit.sync_changeset(%{
          total_allocated: external_data.total_allocated,
          used_amount: external_data.used_amount,
          status: external_data.status
        })
        |> Repo.update()
    end
  end

  @doc """
  Expires benefits that have passed their end date.
  """
  def expire_old_benefits do
    today = Date.utc_today()

    {count, _} =
      Benefit
      |> where([b], b.status == :active)
      |> where([b], b.period_end < ^today)
      |> where([b], is_nil(b.deleted_at))
      |> Repo.update_all(set: [status: :expired, updated_at: DateTime.utc_now()])

    {:ok, count}
  end
end
