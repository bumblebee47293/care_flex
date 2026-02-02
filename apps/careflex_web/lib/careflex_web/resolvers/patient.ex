defmodule CareflexWeb.Resolvers.Patient do
  @moduledoc """
  GraphQL resolvers for patient operations.
  """

  alias CareflexCore.Care

  def list_patients(_parent, args, _resolution) do
    patients = Care.list_patients(
      page: Map.get(args, :page, 1),
      page_size: Map.get(args, :page_size, 50)
    )
    {:ok, patients}
  end

  def get_patient(_parent, %{id: id}, _resolution) do
    case Care.get_patient!(id) do
      nil -> {:error, "Patient not found"}
      patient -> {:ok, patient}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Patient not found"}
  end

  def search_patients(_parent, %{query: query}, _resolution) do
    patients = Care.search_patients_by_name(query)
    {:ok, patients}
  end

  def create_patient(_parent, %{input: input}, resolution) do
    audit_context = build_audit_context(resolution, "create_patient")

    case Care.create_patient(input, audit_context) do
      {:ok, patient} -> {:ok, patient}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def update_patient(_parent, %{id: id, input: input}, resolution) do
    audit_context = build_audit_context(resolution, "update_patient")
    patient = Care.get_patient!(id)

    case Care.update_patient(patient, input, audit_context) do
      {:ok, updated_patient} -> {:ok, updated_patient}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Patient not found"}
  end

  def delete_patient(_parent, %{id: id}, resolution) do
    audit_context = build_audit_context(resolution, "delete_patient")
    patient = Care.get_patient!(id)

    case Care.delete_patient(patient, audit_context) do
      {:ok, deleted_patient} -> {:ok, deleted_patient}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  rescue
    Ecto.NoResultsError -> {:error, "Patient not found"}
  end

  defp build_audit_context(resolution, action) do
    # Extract user context from resolution
    # In production, this would come from authenticated user
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
