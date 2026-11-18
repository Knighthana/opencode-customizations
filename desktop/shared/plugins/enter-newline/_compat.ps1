# Shared helpers for the entry scripts.
#
# The entry scripts run on both Windows PowerShell 5.1 (the version bundled
# with Windows) and PowerShell 7+:
#
#   powershell -File .\install.ps1
#   pwsh        -File .\install.ps1
#
# 5.1 lacks `ConvertFrom-Json -AsHashtable` and `[Text.Encoding]::Latin1`, and
# `Set-Content -Encoding utf8` writes a BOM there. Those differences live here
# so the entry scripts stay readable and keep a single code path.

$script:Utf8NoBom = New-Object Text.UTF8Encoding($false)
$script:Latin1 = [Text.Encoding]::GetEncoding(28591)

# Reads a file as UTF-8 regardless of the host's default ANSI code page.
function Read-Utf8Text([string]$Path) {
  return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
}

# Writes UTF-8 without a BOM; Windows PowerShell 5.1 adds one otherwise.
function Write-Utf8Text([string]$Path, [string]$Text) {
  [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

# Converts the output of JavaScriptSerializer into ordered hashtables, so the
# rest of the scripts can use the same indexing, `.Contains()` and
# `ConvertTo-Json` calls on both hosts.
function ConvertTo-OrderedHashtable([object]$Value) {
  if ($null -eq $Value) { return $null }
  if ($Value -is [string]) { return $Value }

  if ($Value -is [System.Collections.IDictionary]) {
    $result = [ordered]@{}

    foreach ($key in $Value.Keys) {
      $result[[string]$key] = ConvertTo-OrderedHashtable $Value[$key]
    }

    return $result
  }

  if ($Value -is [System.Collections.IEnumerable]) {
    return @($Value | ForEach-Object { ConvertTo-OrderedHashtable $_ })
  }

  return $Value
}

# Parses JSON into hashtables on every supported host.
function ConvertFrom-JsonHashtable([string]$Json) {
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    return (ConvertFrom-Json -InputObject $Json -AsHashtable)
  }

  Add-Type -AssemblyName System.Web.Extensions

  $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
  $serializer.MaxJsonLength = [int]::MaxValue

  return (ConvertTo-OrderedHashtable $serializer.DeserializeObject($Json))
}

# Decodes bytes one-to-one (Latin-1), used to scan app.asar for ASCII markers.
function Get-Latin1Text([byte[]]$Bytes, [int]$Offset, [int]$Count) {
  return $script:Latin1.GetString($Bytes, $Offset, $Count)
}
