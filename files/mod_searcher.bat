@ECHO OFF
SETLOCAL ENABLEDELAYEDEXPANSION
SET black=[37;40m

:: Sets the current directory as the working directory - this should fix attempts to run the script as admin.
PUSHD "%~dp0" >nul 2>&1

:: This block of commands is to work with the random command and come up with a random font color.
SET /a CHANCECUBE=(%random% %%100)
IF %CHANCECUBE% LSS 50 SET RANDO=1
IF %CHANCECUBE% GEQ 50 SET RANDO=2
SET /a RANDOMBACK1=(%random% %%6)+ 41
SET /a RANDOMBACK2=(%random% %%5)+ 101
IF %RANDO%==1 SET RANDOCOLOR=[97;%RANDOMBACK1%m
IF %RANDO%==2 SET RANDOCOLOR=[30;%RANDOMBACK2%m

ECHO: & ECHO: & ECHO  %RANDOCOLOR% Preparing for search %black%

:: Error message if no mods folder was found, assume user put script in the wrong location.
IF NOT EXIST "%CD%/mods" (
	CLS
	ECHO: & ECHO: & ECHO: & ECHO: & ECHO  %RANDOCOLOR% OOPS - No folder named 'mods' was found. %black%  & ECHO: & ECHO  %RANDOCOLOR% To work, this BAT script needs to be copied to and run from the main folder of a profile. %black% & ECHO: & ECHO: & ECHO:
	PAUSE & EXIT [\B]

)

CD "%CD%/mods"
:: If it doesn't exist yet create a temp folder for holding temp files, and then extract contents of the JAR files out into txt files.
IF NOT EXIST "%CD%/mod_searcher_working" MD mod_searcher_working

:: Disalbing delayed expansion and sending to a function allows correctly using file names containing exlamation marks !
setlocal enableextensions
setlocal disabledelayedexpansion
FOR %%i IN ("*.jar") DO (
	SET "TEMP=%%i"
	CALL :functiontextexport
)
setlocal enabledelayedexpansion

:: The function to print which allows special characters to get used.
GOTO :skipfunctiontextexport
:functiontextexport
	tar -x -O -f "%TEMP%" > "mod_searcher_working/%TEMP%.txt"
GOTO :EOF
:skipfunctiontextexport

PUSHD mod_searcher_working

ECHO: & ECHO  %RANDOCOLOR% Prepartion done %black%
:search_start
ECHO: & ECHO: & ECHO:
SET /p "SEARCHFOR=%RANDOCOLOR% Enter string to look for: %black%"

:: Searches temp txt files for the search string entered.
FINDSTR /m "%SEARCHFOR%" "*.jar.txt" > mods_found.txt


FOR %%R IN (mods_found.txt) DO IF %%~zR LSS 1 (
	ECHO %RANDOCOLOR%  No mods found with that search string. %black% & ECHO:
	CHOICE /C YQ /M "%RANDOCOLOR% Press [Y] to enter another search or [Q] to quit. %black%"
	IF !ERRORLEVEL!==1 CLS & GOTO :search_start
	IF !ERRORLEVEL!==2 GOTO :done
)

:: What to do if mods were found containing the search string
ECHO %RANDOCOLOR%  Found mods that contain %SEARCHFOR%: %black%
ECHO:

:: Another fancy way to disable delayed expansion and send to a function to allow special characters like !
setlocal enableextensions
setlocal disabledelayedexpansion
FOR /F "tokens=*" %%L IN (mods_found.txt) DO (
    set "line=%%L"
	CALL :functiondisplaynames
)
setlocal enabledelayedexpansion

:: The function to print which allows special characters to get used.
GOTO :skipfunctiondisplaynames
:functiondisplaynames
	ECHO 	%RANDOCOLOR% %line:~0,-4% %black%
GOTO :EOF
:skipfunctiondisplaynames

ECHO:
CHOICE /C YQ /M "%RANDOCOLOR% Press [Y] to enter another search or [Q] to quit. %black%"
IF !ERRORLEVEL!==1 (
	CLS
	GOTO :search_start
)
	
:: Remove the working folder
:done
POPD
@RD	 /s /q mod_searcher_working
