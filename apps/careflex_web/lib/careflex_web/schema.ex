defmodule CareflexWeb.Schema do
  @moduledoc """
  Main GraphQL schema for CareFlex API.

  Provides queries, mutations, and subscriptions for:
  - Patient management
  - Appointment scheduling
  - Benefits tracking
  - Real-time updates
  """

  use Absinthe.Schema

  import_types CareflexWeb.Schema.PatientTypes
  import_types CareflexWeb.Schema.AppointmentTypes
  import_types CareflexWeb.Schema.BenefitTypes
  import_types CareflexWeb.Schema.NotificationTypes

  query do
    import_fields :patient_queries
    import_fields :appointment_queries
    import_fields :benefit_queries
  end

  mutation do
    import_fields :patient_mutations
    import_fields :appointment_mutations
    import_fields :benefit_mutations
  end

  subscription do
    import_fields :appointment_subscriptions
  end

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(CareflexCore, CareflexCore.DataLoader.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end
end
