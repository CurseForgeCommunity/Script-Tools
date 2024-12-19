@ECHO OFF
setlocal enabledelayedexpansion
TITLE modID scanner
color 1E
prompt [modID scanner]:
PUSHD "%~dp0" >nul 2>&1
SET "HERE=%cd%"
SET "TABCHAR=	"
  
IF NOT EXIST "%HERE%\mods" (
   ECHO: && ECHO: && ECHO    PROBLEM - NO MODS FOLDER FOUND && ECHO:
   ECHO    PLACE THIS modId SCANNER IN THE MAIN MODPACK OR SERVER FOLDER && ECHO    DO NOT PUT INSIDE THE MODS FOLDER ITSELF && ECHO: && ECHO:
   PAUSE && EXIT [\B]

)

ECHO: & ECHO   MAKING LIST OF FILES - PLEASE WAIT... & ECHO:

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

:: DETERMINES WHICH PRIMARY MODLOADER TYPE TO USE - NEOFORGE, FORGE, FABRIC

IF NOT EXIST "minecraftinstance.json" GOTO :askmodloadertype

ECHO   FOUND A CURSEFORGE minecraftinstance.json - USING IT TO SET PROFILE TYPE! & ECHO:

REM Character escaping special characters that break the powershell calls below.  Please stop putting speical characters in names, thx.
SET "THISLOC=%CD%"
SET "THISLOC=!THISLOC:'=`'!"
SET "THISLOC=!THISLOC:[=`[!"
SET "THISLOC=!THISLOC:]=`]!"

FOR /F "tokens=1-3 delims=-" %%A IN ('powershell -Command "$json=Get-Content -Raw -Path '!THISLOC!\minecraftinstance.json' | Out-String | ConvertFrom-Json; $json.baseModLoader.name"') DO (
   IF /I %%A==FORGE SET MODLOADER=FORGE
   IF /I %%A==NEOFORGE SET MODLOADER=NEOFORGE
   IF /I %%A==FABRIC SET MODLOADER=FABRIC
)
FOR /F "tokens=1-3 delims=." %%A IN ('powershell -Command "$json=Get-Content -Raw -Path '!THISLOC!\minecraftinstance.json' | Out-String | ConvertFrom-Json; $json.baseModLoader.minecraftVersion"') DO (
   IF %%A==1 SET MCMAJOR=%%B & SET MCMINOR=%%C >nul 2>&1
   IF %%A NEQ 1 SET MCMAJOR=%%A & SET MCMINOR %%B >nul 2>&1
   IF NOT DEFINED MCMINOR SET MCMINOR=0
   SET MCMAJOR=!MCMAJOR: =!
)

IF DEFINED MODLOADER IF DEFINED MCMAJOR GOTO :launch

:askmodloadertype
   CLS
	ECHO: & ECHO: & ECHO   PLEASE SELECT WHICH MODLOADER TYPE YOUR PROFILE LAUNCHES WITH! & ECHO:
   ECHO   ^[1^] - FORGE & ECHO   ^[2^] - NEOFORGE & ECHO   ^[3^] - FABRIC & ECHO:
   SET /P SCRATCH="  " <nul
	CHOICE /C 123Q /M "- - Press a number, or [Q] to quit."
	IF !ERRORLEVEL!==1 SET MODLOADER=FORGE
	IF !ERRORLEVEL!==2 SET MODLOADER=NEOFORGE
   IF !ERRORLEVEL!==3 SET MODLOADER=FABRIC
   IF !ERRORLEVEL!==4 PAUSE & EXIT [\B]

:redoversionentry
CLS
ECHO: & ECHO:
ECHO   ENTER THE MINECRAFT VERSION
ECHO:
ECHO    example: 1.12.2
ECHO    example: 1.20.1
ECHO:
ECHO   ENTER THE MINECRAFT VERSION
ECHO: & ECHO:
SET /P SCRATCH="  ENTRY: " <nul
SET /P MINECRAFT=

IF "!MINECRAFT:~0,2!" NEQ "1." (
   ECHO: & ECHO   I don't think you entered a correct Minecraft version, please press any key and try again! & ECHO:
   PAUSE
   GOTO :redoversionentry
)

SET "MCMINOR="
FOR /F "tokens=2,3 delims=." %%B IN ("!MINECRAFT!") DO (
    SET /a MCMAJOR=%%B
    SET /a MCMINOR=%%C >nul 2>&1
)
IF NOT DEFINED MCMINOR SET /a MCMINOR=0

CLS

:launch

ECHO   SCANNING MOD FILES - PLEASE WAIT... .. . & ECHO:

:: First step - because of the ubiquity of the 'Connector' mod allowing people to use fabric mods on forge/neoforge profile,
:: determine which JAR files are present which have no mods.toml/neoforge.toml files but do have a fabric.mod.json

IF !MODLOADER!==FORGE SET "TOML=mods.toml"
IF !MODLOADER!==NEOFORGE ( IF !MCMAJOR!==20 ( IF !MCMINOR!==1 ( SET "TOML=mods.toml" ) ELSE ( SET "TOML=neoforge.mods.toml" )) ELSE ( SET "TOML=neoforge.mods.toml" ) )

IF !MODLOADER!==FABRIC (
   REM IF MODLOADER IS FABRIC DETECT FABRIC LAST SO THAT IT IS THE FINAL ONE TO APPLY
   FOR /L %%T IN (0,1,!SERVERMODSCOUNT!) DO (
      tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\!TOML! >nul 2>&1
      IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FORGE"
      ver >nul
      tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\fabric.mod.json >nul 2>&1
      IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FABRIC"

      IF NOT DEFINED SERVERMODS[%%T].mltype SET "SERVERMODS[%%T].mltype=IDK"
   )
) ELSE (
   REM IF MODERN STYLE
   IF !MCMAJOR! GTR 12 (
      REM IF MODLOADER IS NEOFORGE OR FORGE DETECT LAST SO THAT IT IS THE FINAL ONE TO APPLY
      FOR /L %%T IN (0,1,!SERVERMODSCOUNT!) DO (
         tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\fabric.mod.json >nul 2>&1
         IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FABRIC"
         ver >nul
         tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\!TOML! >nul 2>&1
         IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FORGE"

         IF NOT DEFINED SERVERMODS[%%T].mltype SET "SERVERMODS[%%T].mltype=IDK"
      )
   ) ELSE (
      REM IF OLD STYLE - 1.12.2 AND OLDER
      FOR /L %%T IN (0,1,!SERVERMODSCOUNT!) DO (
         REM IF MODLOADER IS FORGE DETECT LAST SO THAT IT IS THE FINAL ONE TO APPLY
         tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\fabric.mod.json >nul 2>&1
         IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FABRIC"
         ver >nul
         tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *mods.toml >nul 2>&1
         IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=NEWFORGE"
         ver >nul
         tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" mcmod.info >nul 2>&1
         IF !ERRORLEVEL!==0 SET "SERVERMODS[%%T].mltype=FORGE"
         ver >nul

         IF NOT DEFINED SERVERMODS[%%T].mltype SET "SERVERMODS[%%T].mltype=IDK"
      )
   )
)

REM Redirects script if scanning old Forge types
IF !MCMAJOR! LEQ 12 IF !MODLOADER!==FORGE GOTO :scanoldforge

:: BEGIN SCANNING MODERN VERSION FILES

:: For each found jar file - uses tar command to output using STDOUT the contents of the mods.toml.  For each line in the STDOUT output the line is checked.
:: First a trigger is needed to determine if the [mods] section has been detected yet in the JSON.  Once that trigger variable has been set to Y then 
:: the script scans to find the modID line.  A fancy function replaces the = sign with _ for easier string comparison to determine if the modID= line was found.
:: This should ensure that no false positives are recorded.

FOR /L %%T IN (0,1,!SERVERMODSCOUNT!) DO (
   SET COUNT=%%T
   SET /a COUNT+=1
   ECHO SCANNING !COUNT!/!ACTUALMODSCOUNT! - !SERVERMODS[%%T].file!

   IF !SERVERMODS[%%T].mltype!==FORGE (


      SET /a MODIDLINE=0
      SET MODID[0]=x
      SET FOUNDMODPLACE=N

      REM Sends the mods.toml to standard output using the tar command in order to set the ERRORLEVEL - actual output and error output silenced

      tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\mods.toml >nul 2>&1
 
      IF !ERRORLEVEL!==0 FOR /F "delims=" %%X IN ('tar -xOf "%HERE%\mods\!SERVERMODS[%%T].file!" *\!TOML!') DO (
    
      SET "TEMP=%%X"
      IF !FOUNDMODPLACE!==Y IF "!TEMP!" NEQ "!TEMP:modId=x!" (
         SET "TEMP=!TEMP: =!"
         SET "TEMP=!TEMP:%TABCHAR%=!"
         SET "TEMP=!TEMP:#mandatory=!"
         :: CALLs a special function to replace equals with underscore characters for easier detection.
         CALL :l_replace "!TEMP!" "=" ";" "TEMP"
      )
      :: Uses the variable replacement method to find if the current line has modID in the string.
      IF !FOUNDMODPLACE!==Y IF "!TEMP!" NEQ "!TEMP:modId;=x!" (
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

   IF !SERVERMODS[%%T].mltype!==FABRIC (
      SET "SERVERMODS[%%T].deps=;"
      SET /a JSONLINE=0
      SET FOUNDDEPENDS=N
      SET SINGLELINEJSON=N

      REM Uses STDOUT from tar command to loop through each line in the fabric.mod.json file of each mod file.
      FOR /F "delims=" %%I IN ('tar -xOf "mods\!SERVERMODS[%%T].file!" fabric.mod.json') DO (
  
         REM Sets a temp variable equal to the current line for processing, and replaces " with ; for easier loop delimiting later.
         SET "TEMP=%%I"
         SET "TEMP=!TEMP:"=;!"

         REM MODID DETECTION
         REM If the line contains the modid then further process line and then set ID equal to the actual modid entry.
         IF "!TEMP!" NEQ "!TEMP:;id;=x!" (
            IF !JSONLINE! NEQ 0 (

               SET "TEMP=!TEMP:%TABCHAR%=!"
               SET "TEMP=!TEMP: =!"
               SET "TEMP=!TEMP::=!"
               :: Removes unicode greater than and less than codes, for some reason fabric authors have started doing this?
               SET "TEMP=!TEMP:\u003d=!"
               SET "TEMP=!TEMP:\u003e=!"
               REM Normal id delims detection
               FOR /F "tokens=1-3 delims=;" %%Q IN ("!TEMP!") DO (
                  SET SERVERMODS[%%T].id=%%R
               )
            ) ELSE (
               REM Detection for cases when JSON files are formatted to all be on one line instead of multiple lines.
               REM This method is REALLY slow.  Only to be used here if the CMD way if it's detected that the JSON is formatted onto one line.

               REM Sets single quotes in file names to have a powershell escape character in front.
               SET "THISFILENAME=mods\!SERVERMODS[%%T].file!"
               SET "THISFILENAME=!THISFILENAME:'=`'!"
               FOR /F %%A IN ('powershell -Command "$json=(tar xOf "!THISFILENAME!" fabric.mod.json) | Out-String | ConvertFrom-Json; $json.id"') DO ( SET SERVERMODS[%%T].id=%%A )
            )
         )

         REM DEPENDS DETECTION

         REM If JSON is only one line
         IF "!TEMP!" NEQ "!TEMP:;depends;=x!" IF !JSONLINE!==0 (
            REM Sets single quotes in file names to have a powershell escape character in front.
               SET "THISFILENAME=mods\!SERVERMODS[%%T].file!"
               SET "THISFILENAME=!THISFILENAME:'=`'!"

            REM Makes a list of dependencies excluding a few to be ignored.  Semicolons used as a spacer in the holder variable.  If someone uses a semicolon in their dependency name, I swear to god...
            FOR /F %%A IN ('powershell -Command "$json=(tar xOf "!THISFILENAME!" fabric.mod.json) | Out-String | ConvertFrom-Json; $json.depends.psobject.properties.name"') DO (
               IF %%A NEQ fabric IF %%A NEQ fabricloader IF %%A NEQ fabric-api IF %%A NEQ minecraft IF %%A NEQ java SET "SERVERMODS[%%T].deps=!SERVERMODS[%%T].deps!%%A;"
            )
         )

         REM If JSON is on multiple lines.  Anything being looked for is never on the first line of these, so if JSONlINE is not 0 then we can assume this works.
         REM The logic for pseudo-parsing the JSON isn't perfect, but it's fast(er) - than calling powershell hundreds of individual times.
         REM It will record multiple properties values instead of names if a property has values that bleed over into new lines for the array. [ stuff, stuff, stuff ]
         IF !JSONLINE! NEQ 0 (
            REM If the depends value was found in a previous loop but the }, string is found - set the FOUDNDEPENDS variable back equal to N to stop recording entries.
            IF !FOUNDDEPENDS!==Y IF "!TEMP!" NEQ "!TEMP:},=x!" SET FOUNDDEPENDS=N
            REM If the depends value was found in a previous loop and no JSON value ending strings are found - record the dependency entry (ignores common entries that aren't relevant)
            IF !FOUNDDEPENDS!==Y IF "!TEMP!"=="!TEMP:}=x!" IF "!TEMP!"=="!TEMP:]=x!" (
               FOR /F "tokens=1-4 delims=;" %%a IN ("!TEMP!") DO ( SET "TEMP2=%%b" & SET "TEMP3=%%d")
               IF !TEMP2! NEQ fabric IF !TEMP2! NEQ fabricloader IF !TEMP2! NEQ fabric-api IF !TEMP2! NEQ minecraft IF !TEMP2! NEQ java SET "SERVERMODS[%%T].deps=!SERVERMODS[%%T].deps!!TEMP2!;"
               IF !TEMP2!==java (
                  :: Cleans string to a number (hopefully) by stripping away the following things that could be next to it.
                  SET "TEMP3=!TEMP3: ==!"
                  SET "TEMP3=!TEMP3:^==!"
                  SET "TEMP3=!TEMP3:<=!"
                  SET "TEMP3=!TEMP3:>=!"
                  SET "TEMP3=!TEMP3:\u003d=!"
                  SET "TEMP3=!TEMP3:\u003e=!"
                  CALL :l_replace "!TEMP3!" "=" "" "TEMP3"
                  SET SERVERMODS[%%T].java=!TEMP3! >nul 2>&1
               )
            )
            REM If the depends string is found set FOUNDDEPENDS Y for discovery in the next loop iteration.
            IF !FOUNDDEPENDS!==N IF "!TEMP!" NEQ "!TEMP:;depends;=x!" SET FOUNDDEPENDS=Y
         )
         REM Increases the integer value of JSONLINE - this variable is only used to determine if the JSON is the compact 1 line version or has multiple lines.
         SET /a JSONLINE+=1
      )
   )
)
GOTO :report
:: END SCANNING MODERN VERSION STYLES


:scanoldforge
:: BEGIN SCANNING OLD VERSION FILES

:: For each found jar file - uses tar command to output using STDOUT the contents of the mods.toml.  For each line in the STDOUT output the line is checked.
:: First a trigger is needed to determine if the [mods] section has been detected yet in the JSON.  Once that trigger variable has been set to Y then 
:: the script scans to find the modID line.  A fancy function replaces the = sign with _ for easier string comparison to determine if the modID= line was found.
:: This should ensure that no false positives are recorded.


FOR /L %%t IN (0,1,!SERVERMODSCOUNT!) DO (
   SET COUNT=%%t
   SET /a COUNT+=1
   ECHO SCANNING !COUNT!/!ACTUALMODSCOUNT! - !SERVERMODS[%%t].file!

   IF !SERVERMODS[%%t].mltype!==FORGE (
      FOR /F "delims=" %%X IN ('tar -xOf "mods\!SERVERMODS[%%t].file!" mcmod.info') DO (
         :: Sets a temp variable equal to the current line for processing, and replaces " with ; for easier loop delimiting later.
         SET "TEMP=%%X"
         SET "TEMP=!TEMP:"=;!"
         :: If the line contains the modid then further process line and then set ID equal to the actual modid entry.
         IF "!TEMP!" NEQ "!TEMP:;modid;=x!" (
            SET "TEMP=!TEMP:%TABCHAR%=!"
            SET "TEMP=!TEMP: =!"
            SET "TEMP=!TEMP:[=!"
            SET "TEMP=!TEMP:{=!"
            FOR /F "tokens=3 delims=;" %%A IN ("!TEMP!") DO (
               SET SERVERMODS[%%t].id=%%A
            )
         )
      )
      :: If ID was found record it to the array entry of the current mod number, otherwise set the ID of that mod equal to a dummy string x.
      IF NOT DEFINED SERVERMODS[%%t].id SET SERVERMODS[%%t].id=x
   )
)

:report
CLS

:: Figures out which filename to use, increments a number so that new scans make new files.
IF NOT EXIST "modslist.txt" SET "REPORTNAME=modslist"

IF EXIST "modslist.txt" SET /a NUM=2

:up_num
IF EXIST "modslist.txt" (
   IF EXIST "modslist!NUM!.txt" (
      SET /a NUM+=1
      GOTO :up_num
   ) ELSE ( SET "REPORTNAME=modslist!NUM!" )
)

:: Iterates through the list to find the length of the longest modID.  Only look at mods with a defined/found modID.
:: The equal sign is followed by 80 spaces and a doublequote
SET "EightySpaces=                                                                                "
SET ColumnWidth=0
FOR /L %%A IN (0,1,%SERVERMODSCOUNT%) DO (
   IF DEFINED SERVERMODS[%%A].id CALL :GetMaxStringLength ColumnWidth "!SERVERMODS[%%A].id!"
)

IF /I !MODLOADER!==FORGE SET RUNTYPE=FRG
IF /I !MODLOADER!==NEOFORGE SET RUNTYPE=FRG
IF /I !MODLOADER!==FABRIC SET RUNTYPE=FAB

ECHO ---------------------------------------->!REPORTNAME!.txt

IF !RUNTYPE!==FRG (
   ECHO   !MODLOADER! - 1.!MCMAJOR!.!MCMINOR!>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
   ECHO      modID   -   file name>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
 
   FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (


      IF !SERVERMODS[%%D].mltype!==FORGE (
	      REM Append 80 spaces after the different entry types for later chopping
	      SET "Column=!SERVERMODS[%%D].id!%EightySpaces%"

	      REM Chop at maximum column width, using a FOR loop
	      REM as a kind of "super delayed" variable expansion
	      FOR %%O IN (!ColumnWidth!) DO SET "Column=!Column:~0,%%O!"

	      REM Append artist name and display the result
	      ECHO   !Column!  -   !SERVERMODS[%%D].file!>>!REPORTNAME!.txt

      )
   )

   ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt

   FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==FABRIC SET HASFABRIC=Y )

   IF DEFINED HASFABRIC IF !MCMAJOR! GTR 12 (
      ECHO   FABRIC MODS ^& DEPENDENCIES>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      ECHO      modID   -   file name>>!REPORTNAME!.txt & ECHO              -   dependencies>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (
         IF !SERVERMODS[%%D].mltype!==FABRIC (
	         REM Append 80 spaces after the different entry types for later chopping
	         SET "Column=!SERVERMODS[%%D].id!%EightySpaces%"
            SET "Columndeps=%EightySpaces%"
   
	         REM Chop at maximum column width, using a FOR loop
	         REM as a kind of "super delayed" variable expansion
	         FOR %%W IN (!ColumnWidth!) DO SET "Column=!Column:~0,%%W!"
            FOR %%W IN (!ColumnWidth!) DO SET "Columndeps=!Columndeps:~0,%%W!"
	         REM Append artist name and display the result
	         ECHO   !Column!  -   !SERVERMODS[%%D].file!>>!REPORTNAME!.txt

            SET TEMP=!SERVERMODS[%%D].deps:;=!
     
            IF DEFINED TEMP (
               FOR %%a IN (!SERVERMODS[%%D].deps!) DO (
                  ECHO   !Columndeps!              -   %%a>>!REPORTNAME!.txt
               )
            )
         )
      )
      ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
   )

   FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==IDK SET HASIDK=Y )
   IF DEFINED HASIDK (
      ECHO   THE FOLLOWING JAR FILES WERE FOUND WITH NO ID FILES INSIDE.>>!REPORTNAME!.txt
      ECHO   FILES WITHOUT ID FILES INSIDE CANNOT BE SCANNED FOR modID NAMES.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt

      ECHO   -- While the following files do not have ID files inside, certain types of mods are meant>>!REPORTNAME!.txt
      ECHO      to work by other means - and if compatible with your game version they could be working fine.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
      ECHO   -- The files are listed below so that you can know which don't have modIDs to find.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt

      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==IDK ECHO      !SERVERMODS[%%D].file!>>!REPORTNAME!.txt )
      ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
   )

   PUSHD mods
   FINDSTR /I /M "sinytra.connector" *.jar >nul
   IF !ERRORLEVEL!==0 (
      ECHO   IT WAS FOUND THAT ONE OF THE MOD JAR FILES PRESENT IS THE 'Synytra Connector' MOD.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
      ECHO   -- It is the mod which loads Fabric mods on Forge / Neoforge proifles.>>!REPORTNAME!.txt
      ECHO      This only a message to let you know it's here, if you did not put the mod file here,>>!REPORTNAME!.txt
      ECHO      then it could be that it was installed because a Fabric mod installation put it here as a dependency.>>!REPORTNAME!.txt
      ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
   )
   POPD

   IF !MCMAJOR! LEQ 12 (
      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==NEWFORGE SET HASNEWFRG=Y )
      IF DEFINED HASNEWFRG (
         ECHO   THE FOLLOWING FILES WERE FOUND TO HAVE A MODERN STYLE FORGE/NEOFORGE ID FILE INSIDE>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
         ECHO   -- This means they are coded for newer game versions, and will>>!REPORTNAME!.txt
         ECHO      not work in this Minecraft 1.!MCMAJOR!.!MCMINOR! profile.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
         FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==NEWFORGE ECHO      !SERVERMODS[%%D].file!>>!REPORTNAME!.txt )
         ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      )
      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==FABRIC SET HASFABRIC=Y )
      IF DEFINED HASFABRIC (
         ECHO   THE FOLLOWING JAR FILES WERE FOUND TO HAVE FABRIC MODLOADER ID FILES.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
         ECHO   -- Fabric modloader mods are not compatible with Forge Minecraft 1.!MCMAJOR!.!MCMINOR! profiles.>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
         FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==FABRIC ECHO      !SERVERMODS[%%D].file!>>!REPORTNAME!.txt )
         ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      )
   )
)

IF !RUNTYPE!==FAB (
      ECHO   FABRIC 1.!MCMAJOR!.!MCMINOR!>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      ECHO      modID   -   file name>>!REPORTNAME!.txt & ECHO              -   dependencies>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (
         IF !SERVERMODS[%%D].mltype!==FABRIC (
	         REM Append 80 spaces after the different entry types for later chopping
	         SET "Column=!SERVERMODS[%%D].id!%EightySpaces%"
            SET "Columndeps=%EightySpaces%"
   
	         REM Chop at maximum column width, using a FOR loop
	         REM as a kind of "super delayed" variable expansion
	         FOR %%W IN (!ColumnWidth!) DO SET "Column=!Column:~0,%%W!"
            FOR %%W IN (!ColumnWidth!) DO SET "Columndeps=!Columndeps:~0,%%W!"
	         REM Append artist name and display the result
	         ECHO   !Column!  -   !SERVERMODS[%%D].file!>>!REPORTNAME!.txt

            SET TEMP=!SERVERMODS[%%D].deps:;=!
     
            IF DEFINED TEMP (
               FOR %%a IN (!SERVERMODS[%%D].deps!) DO (
                  ECHO   !Columndeps!              -   %%a>>!REPORTNAME!.txt
               )
            )
         )
      )

      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (
         IF !SERVERMODS[%%D].mltype!==FABRIC (
            IF DEFINED SERVERMODS[%%D].java (

               IF !MCMAJOR! LEQ 16 SET /a TARGETJAVA=8
               IF !MCMAJOR! GEQ 18 IF !MCMAJOR! LEQ 19 SET /a TARGETJAVA=17
               IF !MCMAJOR!==20 IF !MCMINOR! LEQ 4 SET /a TARGETJAVA=17
               IF !MCMAJOR!==20 IF !MCMINOR! GEQ 5 SET /a TARGETJAVA=21
               IF !MCMAJOR! GEQ 20 SET /a TARGETJAVA=21
               IF !SERVERMODS[%%D].java! GTR !TARGETJAVA! (
                  SET ISSUEJAVA=Y
                  SET SERVERMODS[%%D].javaissue=Y
               )
            )
         )
      )


   IF DEFINED ISSUEJAVA (
      ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
      ECHO   POTENTIAL ISSUE FOUND WITH THESE FABRIC MOD FILES WHICH REQUIRE A GREATER JAVA VERSION>>!REPORTNAME!.txt
      ECHO   THAN THIS PROFILE IS SUPPOSED TO LAUNCH WITH:>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
      ECHO      Minecraft - 1.!MCMAJOR!.!MCMINOR! / Target Java version !TARGETJAVA!>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt
      ECHO      java version - modID - filename>>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (

         REM Uses FOR loop capturing tickery to set an integer variable equal to a expanded variable
         IF DEFINED SERVERMODS[%%D].javaissue FOR %%A IN (!SERVERMODS[%%D].java!) DO SET /a THISJAVA=%%A

         REM Both variables have been set to be integer variables so that the GTR operation will work correctly for sure.
         IF !THISJAVA! GTR !TARGETJAVA! ECHO      !SERVERMODS[%%D].java! - !SERVERMODS[%%D].id! - !SERVERMODS[%%D].file!>>!REPORTNAME!.txt

      )
      ECHO ---------------------------------------->>!REPORTNAME!.txt & ECHO:>>!REPORTNAME!.txt
   )

   FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO ( IF !SERVERMODS[%%D].mltype!==FORGE SET HASFORGE=Y )

   IF DEFINED HASFORGE (
      ECHO ---------------------------------------->>!REPORTNAME!.txt
      ECHO   !MODLOADER! MODS>>!REPORTNAME!.txt & ECHO ---------------------------------------->>!REPORTNAME!.txt

      FOR /L %%D IN (0,1,%SERVERMODSCOUNT%) DO (

         IF !SERVERMODS[%%D].mltype!==FORGE (
	         REM Append 80 spaces after the different entry types for later chopping
	         SET "Column=!SERVERMODS[%%D].id!%EightySpaces%"
            SET "Columndeps=%EightySpaces%"
   
	         REM Chop at maximum column width, using a FOR loop
	         REM as a kind of "super delayed" variable expansion
	         FOR %%W IN (!ColumnWidth!) DO SET "Column=!Column:~0,%%W!"
            FOR %%W IN (!ColumnWidth!) DO SET "Columndeps=!Columndeps:~0,%%W!"
	         REM Append artist name and display the result
	         ECHO   !Column!  -   !SERVERMODS[%%D].file!
         )
      )
   )
)

:: Finally, actually, echo the results to the console window!  This way all ECHO's above didn't need to be run twice!
ECHO | TYPE "!REPORTNAME!.txt"

PAUSE & EXIT [\B]


:: FUNCTIONS

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


:: FUNCTION TO REPLACE STRINGS WITHIN VARIABLE STRINGS - hot stuff!
:: l_replace function - reworked to allow any variable name passed to alter.  Needs 4 paramters passed.
:: 4 Paramters:  <variable to edit> <string to find> <replacement string> <variable to edit name>
::
:: EXAMPLE:      CALL :l_replace_ng "!TEMP!" "=" ";" "TEMP"

:l_replace
SET "%~4=x%~1x"
:l_replaceloop
FOR /f "delims=%~2 tokens=1*" %%x IN ("!%~4!") DO (
IF "%%y"=="" SET "%~4=!%~4:~1,-1!" & EXIT /b
SET "%~4=%%x%~3%%y"
)
GOTO :l_replaceloop


:: OG l_replace Version that needed TEMP as variable passed.
:: :l_replace
:: SET "TEMP=x%~1x"
:: :l_replaceloop
:: FOR /f "delims=%~2 tokens=1*" %%x IN ("!TEMP!") DO (
:: IF "%%y"=="" set "TEMP=!TEMP:~1,-1!"&exit/b
:: set "TEMP=%%x%~3%%y"
:: )
:: GOTO :l_replaceloop
