
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

:: Check if Node.js is available
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Node.js is not installed
    echo Installing Node.js is recommended for development features
    echo You can download it from https://nodejs.org
    echo.
    set NODE_AVAILABLE=false
) else (
    echo Node.js found:
    node --version
    set NODE_AVAILABLE=true
)

:: Check if git is available
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Git is not installed or not in PATH
    echo Git is recommended for easy updates
    echo You can download it from https://git-scm.com
    echo.
    set GIT_AVAILABLE=false
) else (
    echo Git found:
    git --version
    set GIT_AVAILABLE=true
)

echo.

:: Set up the application directory
set APP_DIR=e-numbers
set REPO_URL=https://github.com/JARVIS-discordbot/e-numbers.git

echo Setting up E-Numbers application...
echo.

:: Clone or update the repository if git is available
if "%GIT_AVAILABLE%"=="true" (
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
) else (
    if not exist %APP_DIR% (
        echo Creating application directory...
        mkdir %APP_DIR%
        cd %APP_DIR%
        echo.
        echo Please download the application files manually:
        echo 1. Go to: https://github.com/JARVIS-discordbot/e-numbers
        echo 2. Click "Code" > "Download ZIP"
        echo 3. Extract files to: %CD%
        echo.
        pause
    ) else (
        cd %APP_DIR%
    )
)

echo.

:: Check if we're in the right directory and have the necessary files
if not exist api.py (
    echo ERROR: api.py not found
    echo Please ensure all application files are present
    pause
    exit /b 1
)

:: Install Python dependencies using pyproject.toml
echo Installing Python dependencies...
if exist pyproject.toml (
    pip install -e .
) else if exist requirements.txt (
    pip install -r requirements.txt
) else (
    echo Installing basic dependencies...
    pip install flask flask-cors requests apscheduler bleach werkzeug
)

if %errorlevel% neq 0 (
    echo ERROR: Failed to install Python dependencies
    pause
    exit /b 1
)

:: Install Node.js dependencies if available
if "%NODE_AVAILABLE%"=="true" (
    if exist package.json (
        echo Installing Node.js dependencies...
        npm install
        if %errorlevel% neq 0 (
            echo WARNING: Failed to install Node.js dependencies
            echo Development server may not work properly
        )
    )
)

echo.

:: Create start scripts
echo Creating start scripts...

:: Create basic start script
echo @echo off > start_basic.bat
echo echo Starting E-Numbers Application... >> start_basic.bat
echo python api.py >> start_basic.bat
echo pause >> start_basic.bat

:: Create start script with editing
echo @echo off > start_editing.bat
echo echo Starting E-Numbers Application with editing enabled... >> start_editing.bat
echo python api.py --allow-editing >> start_editing.bat
echo pause >> start_editing.bat

:: Create development server script if Node.js is available
if "%NODE_AVAILABLE%"=="true" (
    echo @echo off > start_dev.bat
    echo echo Starting development server... >> start_dev.bat
    echo start "Flask API" python start_server.py >> start_dev.bat
    echo timeout /t 3 ^>nul >> start_dev.bat
    echo npm run dev >> start_dev.bat
    echo pause >> start_dev.bat
)

:: Create update script if git is available
if "%GIT_AVAILABLE%"=="true" (
    echo @echo off > update.bat
    echo echo Updating E-Numbers Application... >> update.bat
    echo git fetch origin >> update.bat
    echo git reset --hard origin/main >> update.bat
    echo pip install -e . >> update.bat
    if "%NODE_AVAILABLE%"=="true" (
        echo npm install >> update.bat
    )
    echo echo Update completed! >> update.bat
    echo pause >> update.bat
)

echo.
echo ==========================================
echo Installation completed successfully!
echo ==========================================
echo.
echo Application files are in: %CD%
echo.
echo Available start options:
echo   • start_basic.bat     - Basic mode (read-only)
echo   • start_editing.bat   - With editing capabilities

if "%NODE_AVAILABLE%"=="true" (
    echo   • start_dev.bat       - Development mode with auto-refresh
)

echo.
echo After starting, open: http://localhost:5000/enumbers.html
echo.

if "%GIT_AVAILABLE%"=="true" (
    echo To update later: run update.bat
) else (
    echo To update: manually download new files from GitHub
)

echo.

:: Ask user which mode to start
set /p START_CHOICE="Start the application now? (1=Basic, 2=Editing, 3=Dev, N=No): "

if "%START_CHOICE%"=="1" (
    echo Starting in basic mode...
    start "E-Numbers App" start_basic.bat
    timeout /t 3 >nul
    start http://localhost:5000/enumbers.html
    echo Application started! Check your browser.
) else if "%START_CHOICE%"=="2" (
    echo Starting with editing enabled...
    start "E-Numbers App" start_editing.bat
    timeout /t 3 >nul
    start http://localhost:5000/enumbers.html
    echo Application started! Check your browser.
) else if "%START_CHOICE%"=="3" (
    if "%NODE_AVAILABLE%"=="true" (
        echo Starting development server...
        start "E-Numbers Dev" start_dev.bat
        timeout /t 5 >nul
        start http://localhost:5173
        echo Development server started! Check your browser.
    ) else (
        echo Development mode requires Node.js
        echo Starting in basic mode instead...
        start "E-Numbers App" start_basic.bat
        timeout /t 3 >nul
        start http://localhost:5000/enumbers.html
        echo Application started! Check your browser.
    )
) else (
    echo Installation complete. Run any of the start scripts when ready.
)

echo.
echo ===========================================
echo Installation Information
echo ===========================================
echo.
echo Files location: %CD%
echo.
echo Start scripts:
echo   • start_basic.bat     - Basic read-only mode
echo   • start_editing.bat   - Full editing capabilities

if "%NODE_AVAILABLE%"=="true" (
    echo   • start_dev.bat       - Development with auto-refresh
)

if "%GIT_AVAILABLE%"=="true" (
    echo   • update.bat          - Update application
)

echo.
echo Default URLs:
echo   • Production: http://localhost:5000/enumbers.html

if "%NODE_AVAILABLE%"=="true" (
    echo   • Development: http://localhost:5173
)

echo.
echo Troubleshooting:
echo   • Ensure Python 3.7+ is installed
echo   • Check Windows Firewall if URLs don't work
echo   • For development features, install Node.js
echo   • For easy updates, install Git
echo.
pause
