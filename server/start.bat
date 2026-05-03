@echo off
REM Starts the Pro-Link PHP dev server.
REM
REM We deliberately do NOT use `-c <our php.ini>` because that fully
REM replaces the system php.ini and drops critical settings the host
REM PHP relies on — most importantly `extension_dir`. On XAMPP that
REM setting points at C:\xampp\php\ext; without it PHP falls back to a
REM compiled-in default of C:\php\ext (which usually doesn't exist),
REM and DB-backed endpoints fail with "could not find driver".
REM
REM Instead we layer our overrides on top of the system php.ini using
REM `-d` flags, so the extension_dir / curl / openssl etc. configured
REM there keep working while we still bump upload limits and ensure
REM pdo_pgsql is loaded.
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
php ^
  -d upload_max_filesize=50M ^
  -d post_max_size=55M ^
  -d memory_limit=256M ^
  -d max_execution_time=60 ^
  -d max_input_time=60 ^
  -d extension=pdo_pgsql ^
  -S 0.0.0.0:8081 -t "%~dp0." "%~dp0router.php"
endlocal
