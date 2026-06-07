@echo off
echo ========================================
echo   Deploy E-Absensi ke Vercel
echo ========================================
echo.

echo [1/3] Building Flutter Web...
flutter build web --release
if errorlevel 1 (
    echo Error: Build failed!
    pause
    exit /b 1
)
echo Build selesai!
echo.

echo [2/3] Checking Vercel login...
vercel whoami
if errorlevel 1 (
    echo.
    echo Anda belum login. Silakan login terlebih dahulu:
    echo.
    vercel login
    if errorlevel 1 (
        echo Error: Login gagal!
        pause
        exit /b 1
    )
)
echo.

echo [3/3] Deploying to Vercel Production...
echo.
vercel --prod
echo.

echo ========================================
echo   Deploy Selesai!
echo ========================================
echo.
echo Buka URL production untuk test aplikasi.
echo.
pause
