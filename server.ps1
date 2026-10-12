# Kaiwa — mini serveur local (aucune installation : PowerShell + navigateur suffisent).
# Sert index.html et enregistre TOUT (leçons importées, progression, réglages) dans le dossier data\.
param([int]$Port = 8765, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataDir = Join-Path $root 'data'
$bakDir = Join-Path $root 'backups'
New-Item -ItemType Directory -Force $dataDir, $bakDir | Out-Null
$url = "http://localhost:$Port/"

# Déjà lancé ? On ouvre simplement le navigateur.
try {
  $r = Invoke-WebRequest -Uri ($url + 'api/ping') -UseBasicParsing -TimeoutSec 2
  if ($r.Content -eq 'kaiwa') { if (-not $NoBrowser) { Start-Process $url }; exit 0 }
} catch {}

# Sauvegarde automatique : une copie zippée de data\ par jour, on garde les 14 dernières.
try {
  $stamp = Get-Date -Format 'yyyy-MM-dd'
  $zip = Join-Path $bakDir "kaiwa-$stamp.zip"
  if ((Get-ChildItem $dataDir -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0 -and -not (Test-Path $zip)) {
    Compress-Archive -Path (Join-Path $dataDir '*') -DestinationPath $zip -Force
  }
  Get-ChildItem $bakDir -Filter 'kaiwa-*.zip' | Sort-Object Name -Descending | Select-Object -Skip 14 | Remove-Item -Force
} catch {}

$mime = @{ '.html'='text/html; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8';
  '.json'='application/json; charset=utf-8'; '.svg'='image/svg+xml'; '.png'='image/png'; '.ico'='image/x-icon';
  '.woff2'='font/woff2'; '.woff'='font/woff'; '.ttf'='font/ttf' }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Send($ctx, [int]$code, [byte[]]$bytes, [string]$type) {
  $res = $ctx.Response
  $res.StatusCode = $code
  $res.ContentType = $type
  $res.Headers['Cache-Control'] = 'no-store'
  $res.ContentLength64 = $bytes.Length
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
  $res.OutputStream.Close()
}
function SendText($ctx, [int]$code, [string]$text, [string]$type = 'text/plain; charset=utf-8') { Send $ctx $code ($utf8.GetBytes($text)) $type }
function KeyFile([string]$k) { Join-Path $dataDir ([Uri]::EscapeDataString($k) + '.json') }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try { $listener.Start() } catch { Write-Host "Impossible d'ouvrir $url : $($_.Exception.Message)" -ForegroundColor Red; Read-Host 'Entrée pour fermer'; exit 1 }
$Host.UI.RawUI.WindowTitle = 'Kaiwa — fenêtre à laisser ouverte'
Write-Host ''
Write-Host '  会話  Kaiwa tourne sur ' -NoNewline; Write-Host $url -ForegroundColor Green
Write-Host "  Données enregistrées dans : $dataDir"
Write-Host '  Laisse cette fenêtre ouverte pendant que tu étudies. Ferme-la pour arrêter.'
if (-not $NoBrowser) { Start-Process $url }

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  try {
    $req = $ctx.Request
    $path = $req.Url.AbsolutePath
    if ($path -eq '/api/ping') { SendText $ctx 200 'kaiwa'; continue }

    if ($path -eq '/api/all' -and $req.HttpMethod -eq 'GET') {
      # Assemble {"clé": <json brut>, ...} sans réanalyser les fichiers.
      $sb = New-Object System.Text.StringBuilder
      [void]$sb.Append('{'); $first = $true
      foreach ($f in Get-ChildItem $dataDir -Filter '*.json' -File) {
        $key = [Uri]::UnescapeDataString([IO.Path]::GetFileNameWithoutExtension($f.Name))
        $raw = [IO.File]::ReadAllText($f.FullName, $utf8).Trim()
        if (-not $raw) { continue }
        if (-not $first) { [void]$sb.Append(',') }
        $first = $false
        [void]$sb.Append((ConvertTo-Json -InputObject $key -Compress)); [void]$sb.Append(':'); [void]$sb.Append($raw)
      }
      [void]$sb.Append('}')
      SendText $ctx 200 $sb.ToString() 'application/json; charset=utf-8'; continue
    }

    if ($path -eq '/api/snapshot' -and $req.HttpMethod -eq 'POST') {
      # copie de sécurité à la demande (avant un effacement de progression)
      if ($req.Headers['X-Kaiwa'] -ne '1') { SendText $ctx 403 'forbidden'; continue }
      $zip = Join-Path $bakDir ('avant-effacement-' + (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss') + '.zip')
      Compress-Archive -Path (Join-Path $dataDir '*') -DestinationPath $zip -Force
      SendText $ctx 200 ([IO.Path]::GetFileName($zip)); continue
    }

    if ($path -eq '/api/kv') {
      if ($req.Headers['X-Kaiwa'] -ne '1') { SendText $ctx 403 'forbidden'; continue }
      $k = $req.QueryString['k']
      if (-not $k) { SendText $ctx 400 'missing key'; continue }
      $file = KeyFile $k
      if ($req.HttpMethod -eq 'GET') {
        if (Test-Path $file) { SendText $ctx 200 ([IO.File]::ReadAllText($file, $utf8)) 'application/json; charset=utf-8' } else { SendText $ctx 200 '' }
        continue
      }
      if ($req.HttpMethod -eq 'PUT') {
        $reader = New-Object IO.StreamReader($req.InputStream, $utf8)
        $body = $reader.ReadToEnd(); $reader.Close()
        $tmp = $file + '.tmp'
        [IO.File]::WriteAllText($tmp, $body, $utf8)
        Move-Item -Force $tmp $file          # écriture atomique : jamais de fichier à moitié écrit
        SendText $ctx 200 'ok'; continue
      }
      if ($req.HttpMethod -eq 'DELETE') { if (Test-Path $file) { Remove-Item -Force $file }; SendText $ctx 200 'ok'; continue }
    }

    # Fichiers statiques (uniquement dans le dossier de l'app, jamais data\ ni backups\)
    if ($req.HttpMethod -eq 'GET') {
      $rel = [Uri]::UnescapeDataString($path).TrimStart('/')
      if (-not $rel) { $rel = 'index.html' }
      $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
      $isApp = $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)
      $blocked = $full.StartsWith($dataDir, [StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($bakDir, [StringComparison]::OrdinalIgnoreCase) -or $full -like '*.ps1' -or $full -like '*.bat'
      if ($isApp -and -not $blocked -and (Test-Path $full -PathType Leaf)) {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $type = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
        Send $ctx 200 ([IO.File]::ReadAllBytes($full)) $type; continue
      }
    }
    SendText $ctx 404 'not found'
  } catch {
    try { SendText $ctx 500 ('erreur : ' + $_.Exception.Message) } catch {}
  }
}
