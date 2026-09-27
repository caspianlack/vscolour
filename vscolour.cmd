@echo off
rem Command Prompt / PowerShell wrapper for VSColour.ps1. Put this folder on your PATH, then run `vscolour` inside any repo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0VSColour.ps1" %*
