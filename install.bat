@echo off
echo ==========================================
echo E-Numbers Application Installer
echo ==========================================
echo.

:: Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ from https://python.org
    pause
    exit /b 1
)

echo Python found:
python --version
echo.

:: Check if pip is available
python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: pip is not available
    echo Please ensure pip is installed with Python
    pause
    exit /b 1
)

echo Downloading application files...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JARVIS-discordbot/e-numbers/main/requirements.txt' -OutFile 'requirements.txt'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JARVIS-discordbot/e-numbers/main/api.py' -OutFile 'api.py'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JARVIS-discordbot/e-numbers/main/enumbers.html' -OutFile 'enumbers.html'"
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/JARVIS-discordbot/e-numbers/main/enumbers.json' -OutFile 'enumbers.json'"

if not exist requirements.txt (
    echo ERROR: Failed to download requirements.txt
    pause
    exit /b 1
)

echo Installing dependencies...
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo ==========================================
echo Installation completed successfully!
echo ==========================================
echo.
echo To run the application:
echo   1. Basic mode: python api.py
echo   2. With editing: python api.py --allow-editing
echo.
echo Then open: http://localhost:5000/enumbers.html
echo.
echo Press any key to start the application now...
pause >nul

echo Starting application in basic mode...
start "E-Numbers App" python api.py
timeout /t 3 >nul
start http://localhost:5000/enumbers.html

echo.
echo Application started! Check your browser.
pause 