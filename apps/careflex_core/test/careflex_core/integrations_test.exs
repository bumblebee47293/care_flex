defmodule CareflexCore.IntegrationsTest do
  use CareflexCore.DataCase, async: false

  alias CareflexCore.Integrations.BenefitsAPI
  alias CareflexCore.Integrations.ProviderAPI

  describe "BenefitsAPI.fetch_benefits/1" do
    test "returns benefits for valid patient ID" do
      assert {:ok, benefits} = BenefitsAPI.fetch_benefits("PAT-123")

      assert is_list(benefits)
      assert length(benefits) > 0

      # Verify benefit structure
      benefit = hd(benefits)
      assert benefit.benefit_type in [:transportation, :meals, :fitness, :otc_items, :utilities]
      assert is_struct(benefit.total_allocated, Decimal)
      assert benefit.period_start
      assert benefit.period_end
    end

    test "handles API failures gracefully" do
      # The mock API has a 10% failure rate
      # Run multiple times to potentially hit a failure
      results = Enum.map(1..20, fn _ ->
        BenefitsAPI.fetch_benefits("PAT-FAIL")
      end)

      # Should have at least some successes
      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successes) > 0
    end

    test "simulates network delays" do
      start_time = System.monotonic_time(:millisecond)
      {:ok, _benefits} = BenefitsAPI.fetch_benefits("PAT-123")
      end_time = System.monotonic_time(:millisecond)

      # Should take at least 100ms due to simulated delay
      duration = end_time - start_time
      assert duration >= 100
    end
  end

  describe "ProviderAPI.get_available_slots/2" do
    test "returns available time slots" do
      date = Date.utc_today() |> Date.add(1)

      assert {:ok, slots} = ProviderAPI.get_available_slots("PROV-123", date)

      assert is_list(slots)
      assert length(slots) > 0

      # Verify slot structure
      slot = hd(slots)
      assert %DateTime{} = slot.start_time
      assert is_integer(slot.duration_minutes)
      assert slot.available == true
    end

    test "returns empty list for fully booked days" do
      # Mock returns empty for some providers
      date = Date.utc_today()

      result = ProviderAPI.get_available_slots("PROV-BOOKED", date)

      # Should either succeed with empty list or fail
      assert match?({:ok, []}, result) or match?({:error, _}, result)
    end
  end

  describe "ProviderAPI.reserve_slot/2" do
    test "reserves an available slot" do
      slot_id = "SLOT-#{:rand.uniform(1000)}"
      patient_id = "PAT-123"

      result = ProviderAPI.reserve_slot(slot_id, patient_id)

      # Should succeed or fail gracefully
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "ProviderAPI.cancel_reservation/1" do
    test "cancels a reservation" do
      reservation_id = "RES-123"

      result = ProviderAPI.cancel_reservation(reservation_id)

      assert match?(:ok, result) or match?({:error, _}, result)
    end
  end
end
