@echo off
setlocal enabledelayedexpansion

:: Sets the current directory as the working directory - this should fix attempts to run the script as admin.
PUSHD "%~dp0" >nul 2>&1

:: If no config folder is found, assume user ran the script from the wrong location.
IF NOT EXIST "config" (
    ECHO: & ECHO: & ECHO   NO FOLDER NAMED 'config' WAS FOUND INSIDE THIS FOLDER & ECHO:
    ECHO   THIS SCRIPT FILE MUST BE COPIED TO AND THEN RUN FROM YOUR MAIN PROFILE FOLDER & ECHO: & ECHO:
    PAUSE & EXIT [\B]
)

SET FOUNDEMPTY=N
SET /a idm=0


REM Loops through each file found for each file format type - toml json json5 snbt cfg.
REM Each file is typed out in a loop function.
REM If the function finds even 1 line to type to output then the idx variable is nonzero and thus not empty of regular characters.
REM If idx is 0 for a loop cycle then display the filename, and set FOUNDEMPTY to Y

ECHO: & ECHO   SCANNING FOR EMPTY CONFIG FILES & ECHO A  ------------------------------ & ECHO: 
FOR %%X IN (toml json json5 snbt cfg) DO (
    SET FILESTRING=*.%%X
    FOR /F "delims=" %%A IN ('WHERE /R "%CD%" *.%%X') DO (
        SET /a idx=0
        FOR /F %%C IN ('type "%%A"') DO (
            SET /a idx+=1
        )
        IF !idx!==0 (
            ECHO   Empty file - %%A
            SET FOUNDEMPTY=Y
            SET /a idm+=1
            SET "MOD[!idm!]=%%A"
        )
    )
)

REM If FOUNDEMPTY was never set to Y by any file, then tell the user and exit the script.
IF !FOUNDEMPTY!==N (
    CLS
    ECHO: & ECHO: & ECHO   NO EMPTY CONFIG FILES WERE FOUND ANYWHERE WITHIN THIS PROFILE FOLDER. & ECHO: & ECHO:
    PAUSE & EXIT [\B]
)

ECHO: & ECHO   ------------------------------ & ECHO: & ECHO   THE ABOVE FOUND CONFIG FILES ARE EMPTY^^! & ECHO:
ECHO   NOTE THAT THE SCRIPT CANNOT DISTINGUISH BETWEEN A CORRUPTED FORMAT FILE AND A REGULARLY EMPTY FILE.
ECHO   IF YOU DELETE EMPTY CONFIG FILES - DEFAULT FILES WILL BE MADE AUTOMATICALLY BY MODS ON RUNTIME.
ECHO: & ECHO:

REM The CHOICE command sets resulting ERRORLEVEL value with keystroke options set by /C,
REM where the ERRORLEVEL number set is that character's position after /C

CHOICE /C:yn /M "Do you want to allow this script to delete those empty files?"

IF !ERRORLEVEL!==2 (
    ECHO: & ECHO   Okay, no files will be deleted.  You can re-run this script if you change your mind. & ECHO: & ECHO:
    PAUSE & EXIT [\B]
)

IF !ERRORLEVEL!==1 (
    CLS
    ECHO: & ECHO   YOU ENTERED 'Y' TO DELETE ALL FOUND EMPTY CONFIG FILES.
    ECHO   IS THIS WHAT YOU MEANT? & ECHO:
    SET /P SCRATCH="   ENTER 'YES' TO DELETE, OR ANYTHING ELSE TO QUIT: %blue% " <nul
    SET /P "ANSWER="
    IF /I !ANSWER!==YES (
        ECHO: & ECHO:
        FOR /L %%X IN (1,1,!idm!) DO (
            ECHO   Deleting config file !MOD[%%X]!
            DEL "!MOD[%%X]!"
        ) 
    )
)
ECHO: & ECHO   Script program exiting^^!  To search again re-run the file. & ECHO:

PAUSE & EXIT [\B]

