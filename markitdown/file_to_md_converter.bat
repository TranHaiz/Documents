@echo off
chcp 65001 > nul
title Convert 1 File To Markdown

:: === 2 bien can chinh ===
set "INPUT_FILE=C:\NGOL_HAq\Docs\pdf\Intro to Bluetooth Low Energy v1.1_1.pdf"
set "OUTPUT_DIR=C:\NGOL_HAq\Docs\md"

:: Goi thang python cua .venv: markitdown.exe la uv trampoline, hong sau khi .venv bi di chuyen
set "PYTHON=C:\NGOL_HAq\Docs\markitdown\.venv\Scripts\python.exe"

echo ============================================================
echo   CONVERT 1 FILE SANG MARKDOWN (MARKITDOWN)
echo ============================================================
echo.

if not exist "%INPUT_FILE%" (
    echo [X] Khong tim thay file: %INPUT_FILE%
    goto :end
)
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

:: Lay ten file khong co phan mo rong de dat ten file .md dau ra
for %%F in ("%INPUT_FILE%") do set "BASE_NAME=%%~nF"
set "OUTPUT_FILE=%OUTPUT_DIR%\%BASE_NAME%.md"

echo [.] Dang xu ly: %INPUT_FILE%
"%PYTHON%" -m markitdown "%INPUT_FILE%" -o "%OUTPUT_FILE%"

if errorlevel 1 (
    echo [X] That bai.
) else (
    echo [V] Thanh cong -^> %OUTPUT_FILE%
)

:end
echo.
echo ============================================================
echo Nhan mot phim bat ky de thoat...
pause > nul
