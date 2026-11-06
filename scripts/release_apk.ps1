# ========================================================
# Script de Release OTA para o EscalaIBAI (PowerShell)
# ========================================================
param (
    [string]$Changelog = "",
    [switch]$ForceUpdate = $false
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "      Lançamento de Release OTA - Escala   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Ler versão do pubspec.yaml
if (-not (Test-Path "pubspec.yaml")) {
    Write-Error "Arquivo pubspec.yaml não encontrado. Execute este script a partir da raiz do projeto."
}

$versionLine = Get-Content "pubspec.yaml" | Where-Object { $_ -match '^version:\s*(.+)$' }
if (-not $versionLine) {
    Write-Error "Não foi possível identificar a versão no pubspec.yaml."
}

$versionStr = ($versionLine -split ':\s*')[1].Trim()
$versionParts = $versionStr -split '\+'
$versionName = $versionParts[0]
$versionCode = if ($versionParts.Count -gt 1) { [int]$versionParts[1] } else { 1 }

Write-Host "Versão detectada: $versionName (Build Code: $versionCode)" -ForegroundColor Green

# 2. Obter changelog
if ([string]::IsNullOrWhiteSpace($Changelog)) {
    $Changelog = Read-Host "Digite o changelog (o que há de novo nesta versão)"
    if ([string]::IsNullOrWhiteSpace($Changelog)) {
        $Changelog = "Correções de bugs e melhorias de desempenho."
    }
}

# 3. Forçar atualização
$forceStr = if ($ForceUpdate) { "true" } else { "false" }

Write-Host ""
Write-Host "=== RESUMO DO RELEASE ===" -ForegroundColor Yellow
Write-Host "Versão: $versionName"
Write-Host "Build Code: $versionCode"
Write-Host "Changelog: $Changelog"
Write-Host "Forçar Atualização: $forceStr"
Write-Host "=========================" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Deseja compilar o APK de release agora? (s/N)"
if ($confirm -notmatch '^[sSyY]') {
    Write-Host "Operação cancelada." -ForegroundColor Yellow
    exit 0
}

# 4. Compilar APK
Write-Host "Compilando APK Release..." -ForegroundColor Cyan
flutter build apk --release

$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Error "APK não encontrado em $apkPath após o build."
}

$apkSizeMB = [math]::Round(((Get-Item $apkPath).Length / 1MB), 2)
Write-Host "APK gerado com sucesso ($apkSizeMB MB): $apkPath" -ForegroundColor Green

$tagName = "v$versionName+$versionCode"

# 5. Publicação no GitHub (opcional via gh cli)
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
$apkUrl = ""

if ($ghInstalled) {
    $publishGitHub = Read-Host "Deseja criar a Release no GitHub automaticamente via 'gh'? (s/N)"
    if ($publishGitHub -match '^[sSyY]') {
        Write-Host "Criando tag e release no GitHub..." -ForegroundColor Cyan
        git tag $tagName -ErrorAction SilentlyContinue
        git push origin $tagName -ErrorAction SilentlyContinue

        gh release create $tagName $apkPath --title "Release $versionName" --notes "$Changelog"
        $apkUrl = gh release view $tagName --json assets --jq '.assets[0].url' 2>$null
        if (-not $apkUrl) {
            $repoUrl = gh repo view --json url --jq '.url' 2>$null
            $apkUrl = "$repoUrl/releases/download/$tagName/app-release.apk"
        }
        Write-Host "Release publicada com sucesso no GitHub!" -ForegroundColor Green
    }
}

if ([string]::IsNullOrWhiteSpace($apkUrl)) {
    $apkUrl = "COLE_AQUI_A_URL_DO_APK"
}

# 6. Comando SQL para registrar no Supabase
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Execute o comando SQL abaixo no SQL Editor do Supabase para liberar o update: " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "INSERT INTO app_versions (platform, version_name, version_code, apk_url, changelog, force_update)" -ForegroundColor White
Write-Host "VALUES ('android', '$versionName', $versionCode, '$apkUrl', '$Changelog', $forceStr);" -ForegroundColor White
Write-Host ""
Write-Host "================================================================================" -ForegroundColor Cyan

