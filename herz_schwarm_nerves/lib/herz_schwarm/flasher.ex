defmodule HerzSchwarm.Flasher do
  @moduledoc """
  Kapselt den eigentlichen Flash-Vorgang (Chip-Identifikation + Firmware
  schreiben) hinter einer stabilen API.

  STUB: Der tatsächliche Aufruf eines Flash-Tools (voraussichtlich
  `espflash`, siehe Konzept-Diskussion) ist noch nicht eingebunden — das ist
  ein separater Cross-Compile-Spike für nerves_system_rpi4. Bis dahin geben
  beide Funktionen `{:error, :not_implemented}` zurück, sodass
  `HerzSchwarm.FlashStation` bereits vollständig gegen dieses Modul getestet
  werden kann.
  """

  @type chip :: :esp32s3 | :esp32c6 | :unknown
  @type target :: :badge | :basestation

  @doc """
  Identifiziert den an `port` angeschlossenen Chip, ohne ihn zu verändern
  (liest nur die ROM-Bootloader-Chip-ID, kein Flash-Zugriff).

  Wichtig für die Sicherheits-Leitplanken: Badge und Basisstation sind beide
  `esp32s3` (identische Chip-ID) und dadurch hierüber NICHT unterscheidbar —
  das Ziel muss vom Nutzer explizit gewählt werden. Die Bridge (`esp32c6`)
  ist über die Chip-ID zuverlässig unterscheidbar und wird von
  `FlashStation` ohnehin nie als Ziel-Port betrachtet.
  """
  @spec identify_chip(String.t()) :: {:ok, chip()} | {:error, term()}
  def identify_chip(_port) do
    {:error, :not_implemented}
  end

  @doc """
  Schreibt die für `target` (:badge oder :basestation) aktuell gestagte
  Firmware (siehe `HerzSchwarm.FirmwareSync`) auf das Gerät an `port`.
  """
  @spec flash(String.t(), target()) :: :ok | {:error, term()}
  def flash(_port, _target) do
    {:error, :not_implemented}
  end
end
