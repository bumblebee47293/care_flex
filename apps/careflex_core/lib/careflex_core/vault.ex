defmodule CareflexCore.Vault do
  @moduledoc """
  Vault for encrypting sensitive PII data using Cloak.

  This vault uses AES-256-GCM encryption to protect:
  - Patient names
  - Email addresses
  - Phone numbers
  - Dates of birth
  - Other sensitive healthcare information
  """

  use Cloak.Vault, otp_app: :careflex_core
end
