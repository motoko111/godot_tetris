@echo off
cd /d %~dp0
cd /d ../
rem プロジェクトのルートパス
set PROJECT_ROOT_PATH=%cd%
set PROJECT_NAME=godot_tetris

set src=%PROJECT_ROOT_PATH%\build\web
set dest=C:\06_js\sandbox_web\godot\%PROJECT_NAME%

rem srcからdestフォルダにコピー
echo %src% to %dest%
xcopy /y /s /e /f %src% %dest%
