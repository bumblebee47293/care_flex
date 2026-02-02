defmodule CareflexWeb.Resolvers.Benefit do
  @moduledoc """
  GraphQL resolvers for benefit operations.
  """

  alias CareflexCore.Benefits

  def get_patient_benefits(_parent, %{patient_id: patient_id}, _resolution) do
    benefits = Benefits.get_patient_benefits(patient_id)
    {:ok, benefits}
  end

  def get_active_benefits(_parent, %{patient_id: patient_id}, _resolution) do
    benefits = Benefits.get_active_benefits(patient_id)
    {:ok, benefits}
  end

  def check_eligibility(_parent, %{patient_id: patient_id, benefit_type: benefit_type, amount: amount}, _resolution) do
    case Benefits.check_eligibility(patient_id, benefit_type, amount) do
      {:ok, benefit} ->
        {:ok, %{
          eligible: true,
          benefit: benefit,
          remaining_balance: CareflexCore.Benefits.Benefit.remaining_balance(benefit),
          reason: nil
        }}

      {:error, :no_active_benefit} ->
        {:ok, %{
          eligible: false,
          benefit: nil,
          remaining_balance: nil,
          reason: "No active benefit found for this type"
        }}

      {:error, :insufficient_balance} ->
        {:ok, %{
          eligible: false,
          benefit: nil,
          remaining_balance: nil,
          reason: "Insufficient balance for requested amount"
        }}

      {:error, :benefit_expired} ->
        {:ok, %{
          eligible: false,
          benefit: nil,
          remaining_balance: nil,
          reason: "Benefit period has expired"
        }}
    end
  end

  def create_benefit(_parent, %{input: input}, resolution) do
    audit_context = build_audit_context(resolution, "create_benefit")

    case Benefits.create_benefit(input, audit_context) do
      {:ok, benefit} -> {:ok, benefit}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def record_usage(_parent, %{benefit_id: benefit_id, input: %{amount: amount}}, resolution) do
    audit_context = build_audit_context(resolution, "record_benefit_usage")

    case Benefits.record_usage(benefit_id, amount, audit_context) do
      {:ok, benefit} -> {:ok, benefit}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def sync_benefits(_parent, %{patient_id: patient_id}, _resolution) do
    case Benefits.sync_external_benefits(patient_id) do
      {:ok, results} ->
        # Extract successful benefits
        benefits = Enum.filter_map(results,
          fn result -> match?({:ok, _}, result) end,
          fn {:ok, benefit} -> benefit end
        )
        {:ok, benefits}

      {:error, reason} ->
        {:error, "Failed to sync benefits: #{inspect(reason)}"}
    end
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
