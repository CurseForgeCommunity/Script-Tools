@ECHO OFF
setlocal enabledelayedexpansion
TITLE modID scanner
color 1E
prompt [modID scanner]:
PUSHD "%~dp0" >nul 2>&1
SET "HERE=%cd%"
  
IF NOT EXIST "%HERE%\mods" (
   ECHO: && ECHO: && ECHO    PROBLEM - NO MODS FOLDER FOUND && ECHO:
   ECHO    PLACE THIS modId SCANNER IN THE MAIN MODPACK OR SERVER FOLDER && ECHO    DO NOT PUT INSIDE THE MODS FOLDER ITSELF && ECHO: && ECHO:
   PAUSE && EXIT [\B]

)


  ECHO: && ECHO Scanning mod JAR files
  :: Goes to mods folder and gets file names lists.  FINDSTR prints only files with .jar found
  
:: Creates list of all mod file names.  Sends the working dir to the mods folder and uses a loop and the 'dir' command to create an array list of file names.
:: A For loop is used with delayedexpansion turned off with a funciton called to record each filename because this allows capturing
:: filenames with exclamation marks in the name.  eol=| ensures that filenames with some weird characters aren't ignored.
SET SERVERMODSCOUNT=0
PUSHD mods
setlocal enableextensions
setlocal disabledelayedexpansion
 FOR /F "eol=| delims=" %%J IN ('"dir *.jar /b /a-d"') DO (
  SET "FILENAME=%%J"
    CALL :functionfilenames

    )
setlocal enabledelayedexpansion
POPD

GOTO :skipfunctionfilenames
:functionfilenames
    SET "SERVERMODS[%SERVERMODSCOUNT%].file=%FILENAME%"
    SET /a SERVERMODSCOUNT+=1
    GOTO :EOF
:skipfunctionfilenames

:: CORRECTS THE MOD COUNT TO NOT INCLUDE THE LAST COUNT NUMBER ADDED
SET /a SERVERMODSCOUNT-=1

:: ACTUALMODSCOUNT is just to set a file count number that starts the count at 1 for the printout progress ECHOs.
SET ACTUALMODSCOUNT=!SERVERMODSCOUNT!
SET /a ACTUALMODSCOUNT+=1





:: BEGIN SCANNING NEW STYLE (MC >1.12.2) mods.toml FILES IN MODS

:: For each found jar file - uses tar command to output using STDOUT the contents of the mods.toml.  For each line in the STDOUT output the line is checked.
:: First a trigger is needed to determine if the [mods] section has been detected yet in the JSON.  Once that trigger variable has been set to Y then 
:: the script scans to find the modID line.  A fancy function replaces the = sign with _ for easier string comparison to determine if the modID= line was found.
:: This should ensure that no false positives are recorded.


FOR /L %%T IN (0,1,!SERVERMODSCOUNT!) DO (
   SET COUNT=%%T
   SET /a COUNT+=1
   ECHO SCANNING !COUNT!/!ACTUALMODSCOUNT! - !SERVERMODS[%%T].file!
   SET /a MODIDLINE=0
   SET MODID[0]=x
   SET FOUNDMODPLACE=N

   REM Sends the mods.toml to standard output using the tar command in order to set the ERRORLEVEL - actual output and error output silenced

   tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\mods.toml >nul 2>&1

  
   IF !ERRORLEVEL!==0 FOR /F "delims=" %%X IN ('tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\mods.toml') DO (
    
      SET "TEMP=%%X"
      IF !FOUNDMODPLACE!==Y IF "!TEMP!" NEQ "!TEMP:modId=x!" (
         SET "TEMP=!TEMP: =!"
         SET "TEMP=!TEMP:#mandatory=!"
         :: CALLs a special function to replace equals with underscore characters for easier detection.
         CALL :l_replace "!TEMP!" "=" "_"
      )
      IF !FOUNDMODPLACE!==Y IF "!TEMP!" NEQ "!TEMP:modId_=x!" (
      :: Uses special carats to allow using double quotes " as delimiters, to find the modID value.
      FOR /F delims^=^"^ tokens^=2 %%Y IN ("!TEMP!") DO SET ID=%%Y
       SET MODID[!MODIDLINE!]=!ID!
       SET /a MODIDLINE+=1
       SET FOUNDMODPLACE=DONE
      )
      :: Detects if the current line has the [mods] string.  If it does then record to a varaible which will trigger checking for the string modId_ to detect the real modId of this mod file.
      IF "!TEMP!" NEQ "!TEMP:[mods]=x!" SET FOUNDMODPLACE=Y
   )
   SET SERVERMODS[%%T].id=!MODID[0]!
)
:: Below skips to finishedscan label skipping the next section which is file scanning for old MC versions (1.12.2 and older).
IF !MCMAJOR! GEQ 13 GOTO :finishedscan

GOTO :skipreplacefunction
:: Function to replace strings within variable strings - hot stuff!
:l_replace
SET "TEMP=x%~1x"
:l_replaceloop
FOR /f "delims=%~2 tokens=1*" %%x IN ("!TEMP!") DO (
IF "%%y"=="" set "TEMP=!TEMP:~1,-1!"&exit/b
set "TEMP=%%x%~3%%y"
)
GOTO :l_replaceloop
:skipreplacefunction

:: END SCANNING NEW STYLE MODS.TOML

:finishedscan

CLS


:: First iterate through the list to find the length of the longest title
SET ColumnWidth=0
FOR /L %%A IN (0,1,%SERVERMODSCOUNT%) DO (
	CALL :GetMaxStringLength ColumnWidth "!SERVERMODS[%%A].id!"
)
ECHO ----------------------------------------
ECHO   MODID      -      FILENAME
ECHO   MODID      -      FILENAME>modslist.txt
ECHO ----------------------------------------
ECHO ---------------------------------------->>modslist.txt
:: The equal sign is followed by 80 spaces and a doublequote
SET "EightySpaces=                                                                                "
FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (
	REM Append 80 spaces after song title
	SET "Column=!SERVERMODS[%%D].id!%EightySpaces%"
   
	REM Chop at maximum column width, using a FOR loop
	REM as a kind of "super delayed" variable expansion
	FOR %%W IN (!ColumnWidth!) DO SET "Column=!Column:~0,%%W!"
	REM Append artist name and display the result
	ECHO   !Column!  -   !SERVERMODS[%%D].file!
   ECHO   !Column!  -   !SERVERMODS[%%D].file!>>modslist.txt
)
ECHO. & ECHO ----------------------------------------
PAUSE
ENDLOCAL
GOTO:EOF

:GetMaxStringLength
:: Usage : GetMaxStringLength OutVariableName StringToBeMeasured
:: Note  : OutVariable may already have an initial value
SET StrTest=%~2
:: Just add zero, in case the initial value is empty
SET /A %1+=0
:: Maximum length we will allow, modify appended spaces accordingly
SET MaxLength=80
IF %MaxLength% GTR !%1! (
	FOR /L %%A IN (!%1!,1,%MaxLength%) DO (
		IF NOT "!StrTest:~%%A!"=="" (
			SET /A %1 = %%A + 1
		)
	)
)
GOTO:EOF


PAUSE
