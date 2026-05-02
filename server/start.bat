@echo off
REM Starts the Pro-Link PHP dev server with the bundled php.ini, which
REM bumps upload_max_filesize / post_max_size / memory_limit so file
REM uploads larger than the stock 2M / 8M defaults work.
REM
REM Usage from PowerShell:
REM   $env:DATABASE_URL="postgresql://..."
REM   .\start.bat
REM
REM (Run this from the `server\` folder.)

setlocal
if "%DATABASE_URL%"=="" (
    echo [pro-link] WARNING: DATABASE_URL is not set. The API will fail
    echo            with `server_misconfigured` until you set it. Example:
    echo            $env:DATABASE_URL="postgresql://...neon.tech/neondb?sslmode=require"
    echo.
)
echo [pro-link] starting dev server on http://0.0.0.0:8081
echo [pro-link] using php.ini: %~dp0php.ini
php -c "%~dp0php.ini" -S 0.0.0.0:8081 router.php
endlocal
