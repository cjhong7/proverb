$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot   # project root (parent of .claude)
$prefix = 'http://localhost:8767/'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $root at $prefix"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request
  $res = $ctx.Response
  try {
    $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($path -eq '/') {
      $html = Get-ChildItem -Path $root -Filter *.html | Select-Object -First 1
      $file = if ($html) { $html.FullName } else { $null }
    } else {
      $file = Join-Path $root ($path.TrimStart('/'))
    }
    if ($file -and (Test-Path $file -PathType Leaf)) {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      switch ($ext) {
        '.html' { $res.ContentType = 'text/html; charset=utf-8' }
        '.js'   { $res.ContentType = 'application/javascript; charset=utf-8' }
        '.css'  { $res.ContentType = 'text/css; charset=utf-8' }
        default { $res.ContentType = 'application/octet-stream' }
      }
      $res.StatusCode = 200
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
      $res.OutputStream.Write($msg, 0, $msg.Length)
    }
  } catch {
    $res.StatusCode = 500
  } finally {
    $res.OutputStream.Close()
  }
}
