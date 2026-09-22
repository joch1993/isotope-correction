@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM Double-click to open the isotope app in your browser.
REM Close the browser tab to quit (this window then closes).
REM
REM If several R versions are installed, picks the NEWEST one.
REM Optional pins (open a NEW window after setx):
REM   setx ISOTOPE_R_VERSION "4.4.1"
REM   setx ISOTOPE_RSCRIPT "C:\Program Files\R\R-4.4.1\bin\x64\Rscript.exe"

REM Re-launch in its own window (first click only)
if /I not "%~1"=="GO" (
  start "isotope_app" cmd /k "%~f0" GO
  exit /b 0
)

REM Safe copies of path vars (avoid "ProgramFiles(x86)" parse bugs)
set "PF=%ProgramFiles%"
set "PF86=%ProgramFiles(x86)%"
set "LAD=%LOCALAPPDATA%"

REM Resolve real directory of this .bat (follows symlink / shortcut target if present)
set "APP_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$i = Get-Item -LiteralPath '%~f0';" ^
  "if ($i.LinkType) { $t = $i.Target; if ($t -is [array]) { $t = $t[0] }; $i = Get-Item -LiteralPath $t };" ^
  "Write-Output $i.DirectoryName" > "%TEMP%\isotope_app_dir.txt" 2>nul
if exist "%TEMP%\isotope_app_dir.txt" (
  set /p APP_DIR=<"%TEMP%\isotope_app_dir.txt"
  del "%TEMP%\isotope_app_dir.txt" >nul 2>&1
)
cd /d "%APP_DIR%"
if errorlevel 1 (
  echo Could not open app folder:
  echo   %APP_DIR%
  goto :fail
)

if not exist "%APP_DIR%\app.R" (
  echo app.R not found next to the real launcher:
  echo   %APP_DIR%
  goto :fail
)

set "RSCRIPT="

REM 1) Exact path override
if defined ISOTOPE_RSCRIPT call :try_rscript "%ISOTOPE_RSCRIPT%"

REM 2) Pin version folder, e.g. ISOTOPE_R_VERSION=4.4.1
if not defined RSCRIPT if defined ISOTOPE_R_VERSION (
  set "VER=%ISOTOPE_R_VERSION%"
  if /I "!VER:~0,2!"=="R-" set "VER=!VER:~2!"
  call :try_root "%PF%\R\R-!VER!"
  if not defined RSCRIPT if defined PF86 call :try_root "%PF86%\R\R-!VER!"
  if not defined RSCRIPT if defined LAD call :try_root "%LAD%\Programs\R\R-!VER!"
)

REM 3) Newest R-* under common install roots
if not defined RSCRIPT call :scan_newest "%PF%\R"
if not defined RSCRIPT if defined PF86 call :scan_newest "%PF86%\R"
if not defined RSCRIPT if defined LAD call :scan_newest "%LAD%\Programs\R"

REM 4) Registry current install
if not defined RSCRIPT (
  for %%K in (
    "HKLM\SOFTWARE\R-core\R64"
    "HKLM\SOFTWARE\R-core\R"
    "HKCU\SOFTWARE\R-core\R64"
    "HKCU\SOFTWARE\R-core\R"
  ) do (
    if not defined RSCRIPT (
      for /f "tokens=2*" %%A in ('reg query %%~K /v InstallPath 2^>nul') do call :try_root "%%B"
    )
  )
)

REM 5) PATH last
if not defined RSCRIPT (
  for /f "delims=" %%A in ('where Rscript 2^>nul') do (
    if not defined RSCRIPT call :try_rscript "%%A"
  )
)

if not defined RSCRIPT (
  echo Could not find a working Rscript.exe.
  echo.
  echo Fix options:
  echo   1^) Install R from https://cran.r-project.org/bin/windows/base/
  echo   2^) Pin a version, then open a NEW window:
  echo        setx ISOTOPE_R_VERSION "4.4.1"
  echo   3^) Or pin the exact exe:
  echo        setx ISOTOPE_RSCRIPT "C:\Program Files\R\R-4.4.1\bin\x64\Rscript.exe"
  goto :fail
)

echo App folder: %APP_DIR%
echo Using:      %RSCRIPT%
echo.
echo Starting isotope_app ...
echo First run may install R packages ^(needs internet^).
echo Close the browser tab to quit.
echo.

REM Install missing packages first (shiny must exist before shiny::runApp)
"%RSCRIPT%" --vanilla -e "options(repos=c(CRAN='https://cloud.r-project.org')); pkgs<-c('shiny','dplyr','ggplot2','ggrepel','readxl','openxlsx','DT','stringr','tidyr','gridExtra'); miss<-pkgs[!vapply(pkgs,requireNamespace,quietly=TRUE,FUN.VALUE=logical(1))]; if(length(miss)){message('Installing missing packages: ',paste(miss,collapse=', ')); install.packages(miss,dependencies=TRUE)}; options(isotope_app.quit_on_close=TRUE); shiny::runApp('.',launch.browser=TRUE,host='127.0.0.1')"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo R exited with code %RC%.
  goto :fail
)
exit /b 0

:fail
echo.
pause
exit /b 1

REM ---------- helpers ----------
:try_rscript
if defined RSCRIPT goto :eof
if "%~1"=="" goto :eof
if not exist "%~1" goto :eof
set "RSCRIPT=%~1"
goto :eof

:try_root
if defined RSCRIPT goto :eof
if "%~1"=="" goto :eof
if exist "%~1\bin\x64\Rscript.exe" (
  set "RSCRIPT=%~1\bin\x64\Rscript.exe"
  goto :eof
)
if exist "%~1\bin\Rscript.exe" set "RSCRIPT=%~1\bin\Rscript.exe"
goto :eof

:scan_newest
if defined RSCRIPT goto :eof
if "%~1"=="" goto :eof
if not exist "%~1\" goto :eof
REM /O:-N = name descending so newer R-4.x is tried first
for /f "delims=" %%D in ('dir /b /ad /o:-n "%~1\R-*" 2^>nul') do (
  if not defined RSCRIPT call :try_root "%~1\%%D"
)
goto :eof
