Set-Location "C:\src\EscalaIBAI"
try {
    & "C:\src\EscalaIBAI\scripts\publish_ota.ps1" -CustomVersionName "1.0.2" -CustomVersionCode 3 -Changelog "Notificacoes inteligentes: escala matutina, alerta para ministros, jejum e novas playlists com dia da semana e texto enxuto"
} catch {
    Write-Host "Erro: $_" -ForegroundColor Red
}
Write-Host "Pressione ENTER para fechar..." -ForegroundColor Yellow
Read-Host

