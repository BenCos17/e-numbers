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

:: Check if git is available
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Git is not installed or not in PATH
    echo Please install Git from https://git-scm.com
    pause
    exit /b 1
)

echo Git found:
git --version
echo.

:: Set up the application directory
set APP_DIR=e-numbers
set REPO_URL=https://github.com/JARVIS-discordbot/e-numbers.git

echo Setting up E-Numbers application...
echo.

:: Clone or update the repository
if exist %APP_DIR% (
    echo Updating existing repository...
    cd %APP_DIR%
    git fetch origin
    git reset --hard origin/main
    echo Repository updated!
) else (
    echo Cloning repository from GitHub...
    git clone %REPO_URL% %APP_DIR%
    cd %APP_DIR%
    echo Repository cloned!
)

echo.

:: Check if we're in the right directory
if not exist requirements.txt (
    echo ERROR: Failed to get application files
    echo Please check your internet connection
    pause
    exit /b 1
)

:: Install Python dependencies
echo Installing Python dependencies...
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
echo Application files are in: %CD%
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
echo.
echo To update the application later, run: git pull origin main
pause 