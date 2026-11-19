@echo off
rem UnlimAroma installer: installs UnlimAroma (full) or UnlimAroma Lite on the car over ADB.
rem   Full: button on the climate screen; grants the overlay and secure-settings permissions,
rem         enables the accessibility service, opens the setup screen.
rem   Lite: a plain app opened from its icon; just installs and opens it.
rem Looks for the APKs next to this file (from GitHub Releases) or in out\ (after build.ps1).
rem If both are there it asks which one. Arguments: full | lite to choose, /q to skip the final pause.
rem Copyright (c) 2026 Alexandru Volovoi. All rights reserved. See LICENSE.
setlocal EnableExtensions
chcp 65001 >nul

set "PKG=aroma.mfkilla.control"
set "ACT=com.mfkilla.aroma.AromaActivity"
set "SVC=aroma.mfkilla.control/com.mfkilla.aroma.AromaService"

set "WANT="
if /i "%~1"=="full" set "WANT=full"
if /i "%~2"=="full" set "WANT=full"
if /i "%~1"=="lite" set "WANT=lite"
if /i "%~2"=="lite" set "WANT=lite"
set "QUIET="
if /i "%~1"=="/q" set "QUIET=1"
if /i "%~2"=="/q" set "QUIET=1"

echo UnlimAroma - установка на машину Li Auto
echo.

rem ---- APKs next to this file (the newest of each wins), else in out\
set "FULL="
for /f "delims=" %%f in ('dir /b /o:d "%~dp0aroma-app*.apk" 2^>nul ^| "%SystemRoot%\System32\findstr.exe" /v /i "lite"') do set "FULL=%~dp0%%f"
if not defined FULL if exist "%~dp0out\aroma-app.apk" set "FULL=%~dp0out\aroma-app.apk"
set "LITE="
for /f "delims=" %%f in ('dir /b /o:d "%~dp0aroma-app-lite*.apk" 2^>nul') do set "LITE=%~dp0%%f"
if not defined LITE if exist "%~dp0out\aroma-app-lite.apk" set "LITE=%~dp0out\aroma-app-lite.apk"
if not defined FULL if not defined LITE goto :no_apk

rem ---- which one: argument, the only one present, or ask
if "%WANT%"=="full" if not defined FULL goto :no_apk
if "%WANT%"=="lite" if not defined LITE goto :no_apk
if defined WANT goto :chosen
if not defined LITE set "WANT=full"
if not defined FULL set "WANT=lite"
if defined WANT goto :chosen
echo Какую версию установить?
echo   1 - UnlimAroma: кнопка «Аромат» прямо на экране климата (служба доступности)
echo   2 - UnlimAroma Lite: обычное приложение, открывается по значку, без особых разрешений
echo На машине может стоять только одна из них: новая встанет вместо старой.
"%SystemRoot%\System32\choice.exe" /c 12 /n /m "Нажмите 1 или 2: "
if errorlevel 2 (set "WANT=lite") else (set "WANT=full")
echo.
:chosen
if "%WANT%"=="lite" (set "APK=%LITE%") else (set "APK=%FULL%")

rem ---- adb: PATH, next to this file, or the usual install places
set "ADB="
where adb >nul 2>nul && set "ADB=adb"
if not defined ADB if exist "%~dp0adb.exe" set "ADB=%~dp0adb.exe"
if not defined ADB if exist "%~dp0platform-tools\adb.exe" set "ADB=%~dp0platform-tools\adb.exe"
if not defined ADB if exist "C:\platform-tools\adb.exe" set "ADB=C:\platform-tools\adb.exe"
if not defined ADB if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not defined ADB goto :no_adb

if "%WANT%"=="lite" (echo Версия: UnlimAroma Lite) else (echo Версия: UnlimAroma)
echo Файл:   %APK%
"%ADB%" start-server >nul 2>nul
set "DEV="
for /f "skip=1 tokens=1,2" %%a in ('"%ADB%" devices') do if "%%b"=="device" set "DEV=%%a"
if not defined DEV goto :no_dev
echo Машина: %DEV%
echo.
if "%WANT%"=="lite" goto :lite

echo [1/4] Установка приложения...
"%ADB%" -s %DEV% install -r -g "%APK%"
if errorlevel 1 goto :install_failed

echo [2/4] Разрешения: окно поверх и автовключение службы после перезагрузки...
"%ADB%" -s %DEV% shell appops set %PKG% SYSTEM_ALERT_WINDOW allow >nul 2>nul
"%ADB%" -s %DEV% shell pm grant %PKG% android.permission.WRITE_SECURE_SETTINGS >nul 2>nul

echo [3/4] Включение службы кнопки на экране климата...
set "CUR="
for /f "usebackq tokens=*" %%s in (`"%ADB%" -s %DEV% shell settings get secure enabled_accessibility_services`) do set "CUR=%%s"
rem (no parenthesised block here: %NEW% inside one would expand before it is set)
echo %CUR% | "%SystemRoot%\System32\find.exe" "%SVC%" >nul
if not errorlevel 1 goto :acc_on
set "NEW=%CUR%:%SVC%"
if "%CUR%"=="" set "NEW=%SVC%"
if "%CUR%"=="null" set "NEW=%SVC%"
"%ADB%" -s %DEV% shell settings put secure enabled_accessibility_services "%NEW%"
:acc_on
"%ADB%" -s %DEV% shell settings put secure accessibility_enabled 1 >nul 2>nul

echo [4/4] Открываю экран настройки на машине...
"%ADB%" -s %DEV% shell am start -n %PKG%/%ACT% >nul 2>nul

echo.
echo Готово. На машине в UnlimAroma нажмите «Найти станции» и выберите свою «Fresh Air»,
echo затем откройте экран климата - там появится кнопка «Аромат».
goto :end

:lite
echo [1/2] Установка приложения...
"%ADB%" -s %DEV% install -r -g "%APK%"
if errorlevel 1 goto :install_failed

echo [2/2] Открываю приложение на машине...
"%ADB%" -s %DEV% shell am start -n %PKG%/%ACT% >nul 2>nul

echo.
echo Готово. На машине в UnlimAroma Lite откройте «Настройки», нажмите «Найти станции»
echo и выберите свою «Fresh Air». Значок можно закрепить в нижней панели или на рабочем столе.
goto :end

:no_apk
echo [ОШИБКА] Не найден файл приложения (aroma-app.apk или aroma-app-lite.apk).
echo Скачайте его со страницы релизов и положите в ту же папку, что и install.bat:
echo   https://github.com/mfkilla13/UnlimAroma/releases
goto :end

:no_adb
echo [ОШИБКА] Не найден adb.exe.
echo Скачайте Android SDK Platform-Tools для Windows:
echo   https://developer.android.com/tools/releases/platform-tools
echo и распакуйте папку platform-tools рядом с install.bat или в C:\platform-tools.
goto :end

:no_dev
echo [ОШИБКА] Машина не подключена.
echo - Машина на P, кабель USB с передачей данных, на машине включена отладка по USB.
echo - В первый раз подтвердите на экране машины «Разрешить отладку по USB».
echo - Закройте другие программы, которые используют adb.
goto :end

:install_failed
echo [ОШИБКА] Установка не удалась, см. сообщение выше.
echo Если там INSTALL_FAILED_UPDATE_INCOMPATIBLE - удалите старую версию UnlimAroma и повторите.
goto :end

:end
echo.
if not defined QUIET pause
endlocal
