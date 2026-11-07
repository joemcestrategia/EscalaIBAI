@echo off
chcp 65001 >nul
title 🚀 Publicador OTA - EscalaIBAI
cd /d "C:\src\EscalaIBAI"
powershell -NoExit -ExecutionPolicy Bypass -File "C:\src\EscalaIBAI\scripts\publish_ota.ps1" -Changelog "Aviso inteligente para o Ministro caso a playlist do culto ainda nao tenha sido montada (vespera a noite ou manha do dia)"
pause
