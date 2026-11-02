<#
  Analisis de dependencias de AudioShare (npm + pub).
  Ejecutar desde la raiz del repositorio:
      powershell -ExecutionPolicy Bypass -File scripts\analizar-dependencias.ps1
  Requiere Node.js/npm y Flutter en el PATH, y conexion a internet.
  Guarda la salida completa en docs\evidencia-dependencias\ y un resumen.md.
#>
$ErrorActionPreference = "Continue"
$out = Join-Path (Get-Location) "docs\evidencia-dependencias"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$fecha = Get-Date -Format "yyyy-MM-dd HH:mm"

function Guardar($nombre, $comando) {
    Write-Host ">> $comando"
    $ruta = Join-Path $out $nombre
    cmd /c "$comando" 2>&1 | Out-File -FilePath $ruta -Encoding utf8
}

# 1) npm: avisos de seguridad (JSON para contar + texto para leer)
Guardar "npm-audit-prod.json"  "npm audit --omit=dev --json"
Guardar "npm-audit-prod.txt"   "npm audit --omit=dev"
Guardar "npm-audit-todo.json"  "npm audit --json"
Guardar "npm-audit-todo.txt"   "npm audit"
Guardar "npm-outdated.txt"     "npm outdated"
Guardar "npm-ls-prod.txt"      "npm ls --omit=dev --all"

# 2) pub: paquetes desactualizados y arbol de dependencias
Guardar "pub-outdated.txt"     "flutter pub outdated"
Guardar "pub-deps.txt"         "flutter pub deps"

function Contar($archivo) {
    try {
        $j = Get-Content (Join-Path $out $archivo) -Raw | ConvertFrom-Json
        $v = $j.metadata.vulnerabilities
        if ($null -eq $v) { return "no se pudo leer (ver el .txt)" }
        return "info $($v.info) / low $($v.low) / moderate $($v.moderate) / high $($v.high) / critical $($v.critical) / total $($v.total)"
    } catch { return "no se pudo leer (ver el .txt; revisar la conexion)" }
}

$resumen = @"
# Resumen de la ejecucion

Ejecutado: $fecha

| Herramienta | Resultado |
| --- | --- |
| npm audit --omit=dev (produccion) | $(Contar "npm-audit-prod.json") |
| npm audit (todo el arbol) | $(Contar "npm-audit-todo.json") |

Salida completa en los archivos de esta carpeta (npm-outdated.txt,
pub-outdated.txt, pub-deps.txt, npm-ls-prod.txt).
"@
$resumen | Out-File -FilePath (Join-Path $out "resumen.md") -Encoding utf8
Write-Host ""
Write-Host $resumen
