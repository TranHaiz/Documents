@echo off
chcp 65001 > nul
title Convert Folder To Markdown

:: === 2 bien can chinh ===
set "INPUT_DIR=C:\NGOL_HAq\Docs\pdf"
set "OUTPUT_DIR=C:\NGOL_HAq\Docs\md"

:: Goi thang python cua .venv: markitdown.exe la uv trampoline, hong sau khi .venv bi di chuyen
set "PYTHON=C:\NGOL_HAq\Docs\markitdown\.venv\Scripts\python.exe"

echo ============================================================
echo   HE THONG CONVERT FILE HANG LOAT SANG MARKDOWN (MARKITDOWN)
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$Python = '%PYTHON%'; $InputDir = '%INPUT_DIR%'; $OutputDir = '%OUTPUT_DIR%'; $Files = Get-ChildItem -Path $InputDir -Recurse -File | Where-Object { $_.Extension -ne '.md' -and $_.Extension -ne '.py' -and $_.Name -notlike '~*' }; $Done = 0; $Skipped = 0; $Failed = 0; Write-Host 'Bat dau quet va chuyen doi du lieu...' -ForegroundColor Cyan; foreach ($File in $Files) { $RelativePath = $File.DirectoryName.Replace($InputDir, '').TrimStart('\'); $TargetOutputDir = if ([string]::IsNullOrEmpty($RelativePath)) { $OutputDir } else { Join-Path -Path $OutputDir -ChildPath $RelativePath }; $OutputFileFullPath = Join-Path -Path $TargetOutputDir -ChildPath ($File.BaseName + '.md'); if (Test-Path -Path $OutputFileFullPath -PathType Leaf) { Write-Host '[SKIP] Da co san:' $OutputFileFullPath -ForegroundColor DarkGray; $Skipped++; continue }; if (-not (Test-Path -Path $TargetOutputDir)) { New-Item -ItemType Directory -Path $TargetOutputDir -Force | Out-Null }; Write-Host '--------------------------------------------------'; Write-Host '[..] Dang xu ly:' $File.Name -ForegroundColor Yellow; & $Python -m markitdown $File.FullName -o $OutputFileFullPath; if ($LASTEXITCODE -eq 0) { Write-Host '[OK] Thanh cong ->' $OutputFileFullPath -ForegroundColor Green; $Done++ } else { Write-Host '[X] That bai voi file:' $File.Name -ForegroundColor Red; $Failed++ } }; Write-Host '--------------------------------------------------'; Write-Host ('Hoan thanh! Converted: ' + $Done + ' - Skipped: ' + $Skipped + ' - Failed: ' + $Failed) -ForegroundColor Cyan;"

echo.
echo ============================================================
echo Nhan mot phim bat ky de thoat...
pause > nul
