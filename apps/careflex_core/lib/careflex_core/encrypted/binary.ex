defmodule CareflexCore.Encrypted.Binary do
  @moduledoc """
  Custom Ecto type for encrypted binary fields using Cloak.
  """

  use Cloak.Ecto.Binary, vault: CareflexCore.Vault
end
