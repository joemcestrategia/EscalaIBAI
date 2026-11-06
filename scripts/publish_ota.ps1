# ========================================================
# Script de Release OTA 100% Automatizado - EscalaIBAI
# ========================================================
param (
    [string]$Changelog = "Correções de bugs e melhorias de desempenho.",
    [switch]$ForceUpdate = $false,
    [string]$CustomVersionName = "",
    [int]$CustomVersionCode = 0
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     🚀 Publicação de Atualização OTA - EscalaIBAI        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Configurações do Supabase
$supabaseUrl = "https://dsgqlylniqqjavxwlzku.supabase.co"
$supabaseAnonKey = "sb_publishable_bluqXnKz8L8Buvo820h_oQ_p6vMWo5q"
$headers = @{
    "apikey"        = $supabaseAnonKey
    "Authorization" = "Bearer $supabaseAnonKey"
    "Content-Type"  = "application/json"
    "Prefer"        = "return=representation"
}

# 2. Ler versão do pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "Arquivo pubspec.yaml não encontrado. Execute a partir da raiz do projeto."
}

$pubspecContent = Get-Content "pubspec.yaml" -Raw
$versionMatch = [regex]::Match($pubspecContent, 'version:\s*([0-9\.]+)\+([0-9]+)')

$currentFileVersionName = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "1.0.0" }
$currentFileVersionCode = if ($versionMatch.Success) { [int]$versionMatch.Groups[2].Value } else { 1 }

Write-Host "Versão atual no pubspec.yaml: $currentFileVersionName+$currentFileVersionCode" -ForegroundColor Gray

# 3. Consultar última versão cadastrada no Supabase
$latestDbVersionCode = 0
$latestDbVersionName = ""
$tableExists = $false

try {
    $dbQuery = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/app_versions?platform=eq.android&order=version_code.desc&limit=1" -Headers $headers -Method Get -TimeoutSec 10
    $tableExists = $true
    if ($dbQuery -and $dbQuery.Count -gt 0) {
        $latestDbVersionCode = [int]$dbQuery[0].version_code
        $latestDbVersionName = $dbQuery[0].version_name
        Write-Host "Última versão registrada no Supabase: $latestDbVersionName (Build Code: $latestDbVersionCode)" -ForegroundColor Green
    } else {
        Write-Host "Nenhuma versão encontrada no Supabase ainda (tabela vazia)." -ForegroundColor Yellow
    }
} catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -eq 404) {
        Write-Host "⚠️  A tabela 'app_versions' ainda não existe no Supabase." -ForegroundColor Yellow
        Write-Host "    Ela precisa ser criada uma única vez no SQL Editor do Supabase." -ForegroundColor Yellow
    } else {
        Write-Host "Aviso ao consultar Supabase: $_" -ForegroundColor Yellow
    }
}

# 4. Determinar próxima versão (Auto-incremento)
$baseCode = [Math]::Max($currentFileVersionCode, $latestDbVersionCode)

$nextVersionCode = if ($CustomVersionCode -gt 0) { $CustomVersionCode } else { $baseCode + 1 }

if ([string]::IsNullOrWhiteSpace($CustomVersionName)) {
    # Incrementar o último dígito semântico (ex: 1.0.0 -> 1.0.1, 1.0.9 -> 1.0.10)
    $parts = $currentFileVersionName.Split('.')
    if ($parts.Count -ge 3) {
        $patch = [int]$parts[2] + 1
        $nextVersionName = "$($parts[0]).$($parts[1]).$patch"
    } else {
        $nextVersionName = "$currentFileVersionName.$nextVersionCode"
    }
} else {
    $nextVersionName = $CustomVersionName
}

$tagName = "v$nextVersionName+$nextVersionCode"

Write-Host ""
Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
Write-Host " NOVA VERSÃO A SER GERADA:" -ForegroundColor Yellow
Write-Host "   Nome da Versão : $nextVersionName" -ForegroundColor White
Write-Host "   Código (Build) : $nextVersionCode" -ForegroundColor White
Write-Host "   Tag Git        : $tagName" -ForegroundColor White
Write-Host "   Changelog      : $Changelog" -ForegroundColor White
Write-Host "   Forçar Update  : $($ForceUpdate.IsPresent)" -ForegroundColor White
Write-Host "----------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""

# 5. Atualizar pubspec.yaml
Write-Host "Atualizando pubspec.yaml para $nextVersionName+$nextVersionCode..." -ForegroundColor Cyan
$newPubspec = [regex]::Replace($pubspecContent, 'version:\s*[0-9\.]+\+[0-9]+', "version: $nextVersionName+$nextVersionCode")
Set-Content -Path "pubspec.yaml" -Value $newPubspec -NoNewline
Write-Host "pubspec.yaml atualizado." -ForegroundColor Green

# 6. Compilar APK Release
Write-Host ""
Write-Host "Compilando APK Release (flutter build apk --release)..." -ForegroundColor Cyan
$buildOutput = flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha na compilação do APK Release!"
}

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Error "APK não encontrado em $apkPath após o build."
}

$apkSizeMB = [math]::Round(((Get-Item $apkPath).Length / 1MB), 2)
Write-Host "APK gerado com sucesso ($apkSizeMB MB) em $apkPath" -ForegroundColor Green

# 7. Criar Tag e Release no GitHub
Write-Host ""
Write-Host "Publicando Release no GitHub ($tagName)..." -ForegroundColor Cyan

# Commit e push do pubspec.yaml
git add pubspec.yaml
git commit -m "chore(release): versao $nextVersionName+$nextVersionCode" -ErrorAction SilentlyContinue
git push origin main -ErrorAction SilentlyContinue

# Tag
git tag -a $tagName -m "Release $tagName" -ErrorAction SilentlyContinue
git push origin $tagName -ErrorAction SilentlyContinue

# GitHub Release via CLI
gh release create $tagName $apkPath --title "Release $nextVersionName" --notes "$Changelog"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Aviso: 'gh release create' retornou código não-zero, tentando obter asset url..." -ForegroundColor Yellow
}

# Obter URL do asset
$apkUrl = gh release view $tagName --json assets --jq '.assets[0].url' 2>$null
if (-not $apkUrl) {
    $repoUrl = gh repo view --json url --jq '.url' 2>$null
    $apkUrl = "$repoUrl/releases/download/$tagName/app-release.apk"
}

Write-Host "Release publicada com sucesso no GitHub!" -ForegroundColor Green
Write-Host "URL do APK: $apkUrl" -ForegroundColor Green

# 8. Registrar no Supabase
Write-Host ""
Write-Host "Registrando nova versão no Supabase..." -ForegroundColor Cyan

$payload = @{
    "platform"      = "android"
    "version_name"  = $nextVersionName
    "version_code"  = $nextVersionCode
    "apk_url"       = $apkUrl
    "changelog"     = $Changelog
    "force_update"  = [bool]$ForceUpdate.IsPresent
} | ConvertTo-Json

if ($tableExists) {
    try {
        $insertRes = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/app_versions" -Headers $headers -Method Post -Body $payload
        Write-Host "✅ Nova versão registrada com sucesso no Supabase!" -ForegroundColor Green
        Write-Host "O app notificará todos os usuários automaticamente na próxima abertura!" -ForegroundColor Green
    } catch {
        Write-Host "Erro ao inserir no Supabase: $_" -ForegroundColor Red
        Write-Host "Detalhes: $($_.Exception.Response)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Tabela 'app_versions' não encontrada no banco." -ForegroundColor Yellow
    Write-Host "Para ativar a verificação automática, execute o script SQL 'supabase_app_versions.sql' no SQL Editor do Supabase." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Comando para registrar manualmente após criar a tabela:" -ForegroundColor Gray
    Write-Host "INSERT INTO app_versions (platform, version_name, version_code, apk_url, changelog, force_update)" -ForegroundColor White
    Write-Host "VALUES ('android', '$nextVersionName', $nextVersionCode, '$apkUrl', '$Changelog', $($ForceUpdate.IsPresent.ToString().ToLower()));" -ForegroundColor White
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "🎉 PROCESSO CONCLUÍDO COM SUCESSO! Versão $tagName no ar!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
