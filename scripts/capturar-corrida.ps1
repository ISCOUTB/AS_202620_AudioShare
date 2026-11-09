<#
  Registra una corrida de EC-01: consulta GET /rooms/{id}/sync y agrega una
  fila a docs\evidencia-corridas.csv.
  Uso (desde la raiz del repo, justo despues de pulsar Reproducir y esperar
  unos segundos a que lleguen los ACK):
    powershell -ExecutionPolicy Bypass -File scripts\capturar-corrida.ps1 `
      -Room <roomId> -Dispositivos "SM-A127M + PC Windows" -Red "Wi-Fi casa" `
      -Notas "sin incidentes"
  Opcional: -Api https://audioshare.iscoutb.dev  (valor por defecto)
            -AcusticoMs 42   (desfase medido con microfono, si lo tienes)
#>
param(
  [Parameter(Mandatory = $true)][string]$Room,
  [string]$Api = "https://audioshare.iscoutb.dev",
  [string]$Dispositivos = "",
  [string]$Red = "",
  [string]$Notas = "",
  [string]$AcusticoMs = ""
)

$csv = Join-Path (Get-Location) "docs\evidencia-corridas.csv"
$reporte = Invoke-RestMethod -Uri "$Api/rooms/$Room/sync" -Method Get

$acks = ($reporte.acks | ForEach-Object { "$($_.receiverId)=$($_.deviationMs)" }) -join "; "
$fila = [pscustomobject]@{
  fecha            = (Get-Date -Format "yyyy-MM-dd HH:mm")
  api              = $Api
  roomId           = $Room
  dispositivos     = $Dispositivos
  red              = $Red
  receptores       = @($reporte.acks).Count
  spreadMs         = $reporte.spreadMs
  umbralMs         = $reporte.thresholdMs
  dentroDelUmbral  = $reporte.withinThreshold
  deviationMs      = $acks
  acusticoMs       = $AcusticoMs
  notas            = $Notas
}

if (Test-Path $csv) { $fila | Export-Csv -Path $csv -Append -NoTypeInformation -Encoding utf8 }
else { $fila | Export-Csv -Path $csv -NoTypeInformation -Encoding utf8 }

$fila | Format-List
Write-Host "Guardado en $csv"
