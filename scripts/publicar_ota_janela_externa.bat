@echo off
chcp 65001 >nul
title 🚀 Publicador OTA - EscalaIBAI
cd /d "C:\src\EscalaIBAI"
powershell -NoExit -ExecutionPolicy Bypass -File "C:\src\EscalaIBAI\scripts\publish_ota.ps1" -CustomVersionName "1.0.2" -CustomVersionCode 3 -Changelog "Notificacoes inteligentes ativadas: escala matutina, alerta para ministros, jejum e novas playlists com dia da semana e texto enxuto"
pause

