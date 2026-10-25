$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('larpblox-body-cache-' + [guid]::NewGuid() + '.lua')
try {
    $source = Get-Content avatar.lua -Raw
    $first = $source.IndexOf('    local fullBodyTemplates')
    $last = $source.IndexOf('    function api.prepareBodyParts', $first)
    [IO.File]::WriteAllText($fixture, $source.Substring($first, $last - $first) + ' return prepareBodyParts')
    $output = npx --offline --package=fengari-node-cli fengari tests/body_template_cache.lua $fixture 2>&1
    $output
    if (-not ($output -match '^PASS:')) { throw 'Body template cache regression failed.' }
} finally {
    Remove-Item -LiteralPath $fixture -ErrorAction SilentlyContinue
    Pop-Location
}
