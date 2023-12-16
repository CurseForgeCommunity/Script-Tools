@echo off
setlocal enabledelayedexpansion
IF NOT EXIST "%cd%\mods" (
  ECHO: & ECHO: & ECHO   NO MODS FOLDER WAS FOUND. & ECHO: & ECHO   THIS BAT GOES IN THE MAIN PROFILE FOLDER NOT **INSIDE** THE MODS FOLDER!
  ECHO: & ECHO:
  PAUSE && EXIT [\B]
)
ECHO.
ECHO Searching 'mods' folder for MCreator mods [Please Wait]
ECHO.
PUSHD mods
findstr /i /m "net/mcreator /procedures/" "*.jar" >final.txt
SORT final.txt > mcreator-mods.txt
DEL final.txt
POPD
MOVE "%cd%\mods\mcreator-mods.txt" "%cd%\mcreator-mods.txt"
CLS
ECHO.
ECHO RESULTS OF Search
ECHO ---------------------------------------------
for /f "tokens=1 delims=" %%i in (mcreator-mods.txt) DO (
  ECHO mcreator mod - %%i
)
ECHO.
ECHO.
ECHO The above mod files were created using MCreator.
ECHO They are known to often cause severe problems because of the way they get coded.
ECHO.
ECHO A txt tile has been generated in this directory named mcreator-mods.txt listing the mod file names for future reference.
ECHO.

PAUSE
