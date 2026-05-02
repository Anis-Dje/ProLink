@echo off
REM Starts the Pro-Link PHP dev server with bumped upload limits.
REM
REM We use `-d key=value` flags rather than `-c <ini-file>` because `-c`
REM tells PHP to ignore the system php.ini entirely. On Windows that
REM means losing `extension_dir` / loaded extensions (notably
REM `pdo_pgsql`) and the API can't reach Neon. `-d` is additive:
REM it keeps every value from the system php.ini and just overrides
REM the upload-related ones we care about.
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
echo [pro-link] upload limits: 50M (file) / 55M (request)
php ^
  -d upload_max_filesize=50M ^
  -d post_max_size=55M ^
  -d memory_limit=256M ^
  -d max_execution_time=60 ^
  -d max_input_time=60 ^
  -d opcache.enable_cli=0 ^
  -d opcache.enable=0 ^
  -d opcache.validate_timestamps=1 ^
  -d opcache.revalidate_freq=0 ^
  -S 0.0.0.0:8081 -t "%~dp0." "%~dp0router.php"
endlocal
