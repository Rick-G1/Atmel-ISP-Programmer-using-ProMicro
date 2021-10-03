@Echo off
rem /******************************************************************************/
rem /*                                                                            */             
rem /*              Batch file to Program AVR parts via AVRDude                   */             
rem /*                                                                            */             
rem /*                     Copyright (c) 2021  Rick Groome                        */
rem /*                                                                            */             
rem /* Permission is hereby granted, free of charge, to any person obtaining a    */
rem /* copy of this software and associated documentation files (the "Software"), */
rem /* to deal in the Software without restriction, including without limitation  */
rem /* the rights to use, copy, modify, merge, publish, distribute, sublicense,   */
rem /* and/or sell copies of the Software, and to permit persons to whom the      */
rem /* Software is furnished to do so, subject to the following conditions:       */
rem /*                                                                            */
rem /* The above copyright notice and this permission notice shall be included in */
rem /* all copies or substantial portions of the Software.                        */
rem /*                                                                            */
rem /* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR */
rem /* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,   */
rem /* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL    */
rem /* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER */
rem /* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    */
rem /* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER        */
rem /* DEALINGS IN THE SOFTWARE.                                                  */
rem /*                                                                            */             
rem /******************************************************************************/
rem 
rem  See below for revision info and documentation 
rem 
rem Sample command lines 
rem   pgmatmel /q /PCOM4 attiny261 zfile 
rem   pgmatmel /q /PCOM4 attiny261 zfile /r /o
rem   pgmatmel /q /P attiny261 "x x\y" /x /F0x01,*,0x03 -v --n
rem 
SETLOCAL 
SET SCRIPTPATH=%~s0&& SET SCRIPTNAME=%0
CALL :TOUPPER SCRIPTNAME
for %%f in ("%SCRIPTNAME%") do set SCRIPTNAME=%%~nf
SET SCRIPTNAME=%SCRIPTNAME:"=%
SET VERSINFO=%SCRIPTNAME% batch file  (c) Rick Groome 2021                   Vers 1.00 (REG)
Echo %VERSINFO%
rem
rem ****************************************************************************
rem *                       User changeable parameters                         *
rem ****************************************************************************
rem 
rem Change DUDEPGM and DUDECFG to where the AVRDUDE program and config file 
rem is located.
rem
SET DUDESW=%ProgramFiles(x86)%\Arduino\hardware\tools\avr
SET DUDEPGM=%DUDESW%\bin\avrdude.exe
SET DUDECFG=%DUDESW%\etc\avrdude.conf
rem
rem Change this comport number to the comport number used by the ProMicro 
rem ISP programmer. (This can be overridden on the command line with /PCOMx or 
rem /SCOMx where 'x' is 1..255)
rem
SET PORT=COM4
rem
rem Fuse section names.   Normally what is here is appropriate for most AVR
rem processors, but certain AVR processors have different section names.
rem If the processor being programmed has different section names, change 
rem the names below to the correct section names or use the /M command line 
rem option.  This batch file programs the sections mentioned in the order listed. 
rem (Note: The the order of fuses in the _F.txt file is the order shown here)
rem Up to 6 sections can be listed here.  List the 'lock' section(s) last. 
rem Sections up to the first section that starts with '*' will be read, 
rem all sections may be written.   The '/M' option for the default listed 
rem below would be '/Mlfuse:hfuse:efuse:*lock'.
rem 
SET FUSESECTS=lfuse, hfuse, efuse, *lock
rem
rem ****************************************************************************
rem *                    End of User changeable parameters                     *
rem ****************************************************************************
GOTO START
rem 
rem ****************************************************************************
rem *                               DOCUMENTATION                              *
rem ****************************************************************************
rem 
rem  Revision Info
rem  1.0	abt 2017
rem  		Initial implementation 
rem  2.0	9-19-21
rem 		Massive rework before posting
rem             1.  Parameters are now checked and the batch file can deal with
rem                 Many oddball parameter like odd number of double quotes, etc.
rem             2.  Parameters and switches can be in any order. The only thing 
rem                 that is fixed is that the partname must be before the filename.
rem 		3.  The .hex extension can be included in the file name. 
rem		4.  All parameters are "consumed" from the command line and extra
rem 		    parameters are flagged/errored in the script. 
rem 		5.  File names can include spaces/paths.
rem 		6.  Terminal mode added. (/T).
rem 		7.  Overwrite without asking switch added (/o).
rem 		8.  AvrDude extra options added. 
rem 		9.  Help messages expanded and long help file added.
rem		10. Fuses 'generisized' to 1..n (instead of fixed lfuse,hfuse, 
rem                 etc) and can be changed in FUSESECTS variable. 
rem 		11. Modifiers for the filenames are now parameterized.(eg _ep.hex).
rem 		12. Debug switch added (but not documented) (/X).
rem 		13. Now all file dirvatives (eg flash,eeprom,fuses) are checked 
rem                 to see if they exist and when programming can program just 
rem 		    one or two of the files if all three files don't exist.  Also 
rem                 all 3 files are checked for deletion on a read operation. 
rem		14. If files have a path, then the path is listed separately for 
rem                 confirm overwrite and some other operations. 
rem 		15. AVRDude is not called if there's nothing to program. 
rem 		16. Quiet switch modified for somewhat quiet and really quiet
rem 		    In somewhat quiet mode (/q) only AVRDude output shown, in 
rem                 really quiet mode (/Q) Nothing is shown.  
rem                 If error in either quiet mode then error msgs are shown and 
rem                 pause is active.
rem 		17. Turn on error lite on programmer if AVRDude fails. 
rem 		18. This revision info section added. 
rem             19. Fixed error lite on message when no comport by calling 
rem		    TURNONERRLITE instead of doing the echo directly.
rem 		20. Added ability to program the ProMicro device with Catrina
rem                 bootloader itself. Use /S to use AVR109 protocol 
rem                 and program the ProMicro.  
rem                 Now programs using 3 different programmers.
rem 		    NOTE: This option does NOT work for terminal mode, 
rem                 because Catrina bootloader times out if no activity
rem                 as will be seen in terminal mode.
rem                 NOTE: Do NOT try to program a part with the bootloader 
rem                 section in the /S mode (You would be modifying the running 
rem                 bootloader itself which will cause the system to hang. 
rem                 (The code went away)) 
rem 		    To program the bootloader you must use it in the slave mode 
rem                 with either a ArduinoIDE or (a different) ProMicro programmer. 
rem             21. Added -* and --* to include parameters with the AVRDudeOpts. 
rem 		    Using this format '-B -*20' will yield '-B 20' on the 
rem                 command line. (same for --). (allows avrdude options to 
rem                 have parameters, if needed.)
rem 		22. Added /M switch for fuse sections. Format is 
rem                 /Mname1:name2:name3:...  as in /Mlfuse:hfuse:efuse:lock
rem                 NOTE: Using colon separators, NOT comma separators 
rem                 (for ease of coding)
rem             23. Removed dependency of the fuse section names using the lock
rem                 name as the defining point for fuses that can be read and 
rem                 written.  Now all fuses can be written, but only fuses up to 
rem                 the first name that starts with '*'.  Rework default names 
rem                 to FUSESECTS=lfuse, hfuse, efuse, *lock
rem
rem 
:LONGHELP
CLS
Echo %VERSINFO% 
Echo:
Echo This program is used to program or read an Atmel AVR processor using 
Echo AVRDUDE and either the ProMicro ISP programmer, the Arduino ISP 
Echo programmer or the ProMicro board itself.  It uses (if programming) 
Echo or creates (if reading) up to three different Intel hex files (and 
Echo command line fuse options) to then call AVRDude, after which it then 
Echo processes the results. 
Echo:
Echo This file is invoked with the following command line: 
Echo:
Echo   %SCRIPTNAME% [switches] uPName HexFile [switches] [AVRDudeOpts]
Echo:
Echo where    (Items in [] are optional.) 
Echo   '%SCRIPTNAME%' is this file (%SCRIPTNAME%.bat)
Echo:
Echo   'Switches'  are any of
Echo:     /? or ? or /H[elp]  Show this Help screen 
Echo:
Echo      /Q          Run quietly.  No console output unless error.
Echo                  No prompt before programming.
Echo                  No pause at end of running.
Echo                  No output from AVRDude unless error. 
if "%WAIT%" == "2" pause
Echo:
Echo:     /q          Run somewhat quietly. No prompt before programming
Echo                  No pause at end of running.  All AVRDude output included
Echo:
Echo      /R          Read contents of part into the filename mentioned.
Echo:
Echo      /O          When reading, overwrite existing files without asking.
Echo:
Echo      /T          Enter AvrDude Terminal mode. 
Echo                  If specified then other parameters are ignored. 
Echo                  (File name not needed but uPName is required)
Echo:
Echo      /P[COMxx]   Use ProMicro ISP programmer on Com port xx 
Echo                  (Replace xx with com number, eg 'COM4')
Echo                  If only /P then use the com port # specified in batch file.
Echo:
Echo      /S[COMxx]   Use to program the ProMicro device (itself) on Com port xx 
Echo                  (Replace xx with com number, eg 'COM4')
Echo                  If only /S then use the com port # specified in batch file.
Echo:
Echo                  If no /P or /S option then use the Arduino ISP programmer. 
Echo:
Echo      /F[Fuses]   Fuse values to program the part with.   Format is 
if "%WAIT%" == "2" pause
Echo                  /Flow,high,extended,lock (eg "/F0x44,0x55,0x66") where the 
Echo                  first value is the fuses for the low fuses, the second 
Echo                  value is for the high fuses, and third value is for the 
Echo                  extended fuses and the final byte is the lock byte.  
Echo                  If fuses are specified by the /F option they override fuse 
Echo                  settings in the fuse file (if it exists).  
Echo                  Fuse values must be in hex and start with '0x'. Use '*'  
Echo                  for fuses you don't want to specify (do not use blank).
Echo                  (Example: /F0x01,*,0x03  will program Low and Extended fuses 
Echo                  to 01 and 03 but will program the High fuse from the fuse 
Echo                  file if it exists or won't program the High fuse if the 
Echo                  fuse file does NOT exist.)
Echo:
Echo   'upName'    The name of the Atmel chip being programmed / read
Echo               This is typically something like ATTINY25 or ATMEGA328
Echo               or similar.  See AVRDude documentation for exact names.
Echo               (This is a required parameter)
Echo:
Echo   'HexFile'   The file name of the file to program the part with or 
Echo               read the file into. It is assumed to be an Intel Hex file. 
Echo               See filename formats below.  If the filename is "nul" then 
Echo               flash/eeprom will not be programmed.  (This can be used to 
Echo               program fuses via the command line /F switch.)
if "%WAIT%" == "2" pause
Echo               (This is a required parameter)
Echo:
Echo   'AVRDudeOpts' Any other options that may be required for AVRDude program. 
Echo               If the AVRDude option is preceded by '-' then it is placed
Echo               in the AVRDude command line AFTER all parameters specified
Echo               by this program. If the AVRDude option is preceded by '--' 
Echo               then it is put in the AVRDude command line BEFORE parameters
Echo               specified by this program.  
Echo               Ex: "-v --n" put -n before any parameters specified by this 
Echo               program and -v after any parameters specified by this program.
Echo               To add option w/ AVRDude Parameter use -*param or --*param.
Echo:		
Echo HexFile is a file path without an extension.  This program will use the 
Echo following file names for each memory area when programming or reading a part:
Echo (Assumes you entered "Filepath" as the file to use)
Echo    Filepath%HEXEXT%      An Intel hex file for flash memory
Echo    Filepath%EPROMSFX%%HEXEXT%   An Intel hex file for EEPROM memory
Echo    Filepath%FUSESFX%%FUSEEXT%    A text file to program the fuses/lock byte with 
Echo:		
Echo When reading a part, each of these three files will be created.
Echo (If any of the files exist when reading, a prompt will be presented to 
Echo ask if it's ok to delete the files)
Echo When programming a part, if only some of the three files exist then only 
if "%WAIT%" == "2" pause
Echo those memory areas will be programmed.
Echo:
Echo "HexFile" can be a full path name as in "C:\SYS\MYSTUFF\MyFile"
Echo:
Echo For use in Windows (no cmd box) you can also create a shortcut to this 
Echo program and then enter the parameters in the 'Target' box after the name 
Echo of this batch file.  
Echo   (ex: TARGET:  "%SCRIPTNAME%" /Q /PCOM3 attiny2313 myfile /F0x33,*,0x55)
Echo:
Echo Other sample command lines: 
Echo   %SCRIPTNAME% attiny261 myfile    
Echo       Programs an ATTiny261 with myfile.hex using ArduinoISP programmer.
Echo   %SCRIPTNAME% /P attiny261 myfile  
Echo       Programs part myfile.hex using ProMicro programmer.
Echo   %SCRIPTNAME% /P attiny261 myfile  /R /Q
Echo       Reads part using ProMicro programmer into file(s) myfile.hex, 
Echo       myfile_ep.hex and myfile_f.txt.    No output unless error. 
Echo:
Echo Further information can be found within this batch file if needed.
Echo:
Echo:
Echo:
Echo:
SET EX=10
SET WAIT=2
Goto DONE
rem
rem ***************************  Short Help file *******************************
:HELP
CLS
Echo %VERSINFO%
Echo:

Echo This program is used to program or read an Atmel AVR processor using 
Echo AVRDUDE and either the ProMicro ISP programmer, the Arduino ISP 
Echo programmer or the ProMicro board itself.  It uses (if programming) 
Echo or creates (if reading) up to three different Intel hex files (and 
Echo command line fuse options) to then call AVRDude, after which it then 
Echo processes the results. 
Echo:
Echo The format of the command line to run the program is 
Echo:
Echo   %SCRIPTNAME% [switches] [/P[COMx]] uPName HexFile [/F[Fuses]] [AVRDudeOpts]
Echo:
Echo Example:  %SCRIPTNAME% /Q /PCOM3 attiny2313 myfile /F0x33,*,0x55
Echo           (Don't include .hex on myfile.hex)
Echo:
Echo Type %SCRIPTNAME% /? for a more complete help screen with other options. 
Echo:
SET EX=10
SET WAIT=2
Goto DONE
rem
rem ****************************************************************************
rem *                            Macros / Subroutines                          *
rem ****************************************************************************
rem 
rem Macro to convert variable to upper case. Call with "CALL :TOUPPER VarName"
:TOUPPER
FOR %%a IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO CALL SET "%1=%%%1:%%a=%%a%%%"
GOTO :EOF
rem
rem 
rem Macro to count the number of characters matching 'ch' in 'stc'.  
rem Call with "CALL :COUNTCHAR ch  (example CALL :COUNTCHAR X)  Where 'ch' 
rem is the character to look for.  Set 'stc' to string value before calling
rem Function returns 'cnt' (#matching chars) and 'cnt2' (#matching chars mod 2)
rem (We could pass the string 'stc' also but the problem with passing 
rem string as parameter is that if the string contains  "/? or "/ ?" or similar 
rem then the call COUNTCHAR will list help for call command. )
:COUNTCHARS
SET /A "cnt=0"
SET /A "cnt2=0"
SET ch=%1
rem SET stc=%2&& rem adding this changes function to "CALL :COUNTCHAR ch string"
:COUNTCHARS1
if NOT defined stc goto :EOF
SET ch2=%stc:~0,1%&& SET stc=%stc:~1%
if "%ch2%" == "%ch%" SET /A "cnt+=1"
SET /a "cnt2=%cnt% %% 2"
goto COUNTCHARS1
rem 
rem 
:TURNONERRLITE
rem A simple CRLF will turn on the error lite
echo: > %PORTST% 
goto :EOF
rem 
rem 
rem Macro to turn on the error lite on the ProMicro programmer if error
rem If the programming failed and we're using the promicro programmer, turn on
rem the error light on the programmer.  This can be done by sending CRLF to programmer
:CKSETERRLITE
if "%EX%" == "0" goto :EOF
if "%PORTST%" == "#" goto :EOF
mode %PORTST% baud=19200 data=8 parity=N > NUL 
SET ERR=%ERRORLEVEL%
rem Do the Echo>comport but discard the "The system cannot find the file 
rem specified." output if comport doesn't exist by calling it and redirecting error
rem  NOTE:  (echo: > %PORTST%  2> NUL  doesn't eliminate msg.)
if "%ERR%"=="0" CALL :TURNONERRLITE 2> NUL
goto :EOF
rem 
rem 
rem Find the bootloader port for the port specified... Call with "CALL :FINDBOOTLOADER COMX"
rem This routine finds all the comports then opens the specified port (%1) at 1200 baud and then checks to see if 
rem a new port "appears" within 8 seconds.  If so, it's the boot port and return BOOTLOADERPORT=theportfound.  
rem If no new port is found then undefine BOOTLOADERPORT
rem 
:FINDBOOTLOADER
SETLOCAL enabledelayedexpansion
SET FNDPORT=0
SET BOOTPORTS=
SET PT=%1
rem Caller must send parameter and parameter must start with 'COM'
if NOT defined PT goto BLDRDN
if /I NOT "%PT:~0,3%" == "COM" goto BLDRDN
for /F "tokens=2 delims=()" %%A IN ('wmic path win32_pnpentity get caption /format:table ^| findstr /c:"COM"') do (
rem For each port in the list, create variable COMX=1, then if port matches input port then note it in FNDPORT
SET %%A=1
if "%%A"=="%PT%" SET FNDPORT=1
)
rem If we didn't find the port specified in %1 then get out
if NOT "%FNDPORT%"=="1" goto BLDRDN
rem Try to open port at 1200baud.    NOTE: Mode will open the port at the speed specified.  Err=0 if port exists
mode %PT% baud=1200 data=8 parity=n > NUL
if NOT "%ERRORLEVEL%"=="0" goto BLDRDN
SET /A "x=0"
:BLDR1
TIMEOUT /T 1 >NUL
SET BOOTPORTS=
rem echo Checking ports ...
for /F "tokens=2 delims=()" %%A IN ('wmic path win32_pnpentity get caption /format:table ^| findstr /c:"COM"') do (
rem If current comport is NOT defined then add it to BOOTPORTS
if NOT defined %%A if defined BOOTPORTS  (SET BOOTPORTS=!BOOTPORTS! %%A) else SET BOOTPORTS=%%A
)
rem If there's a space in BOOTPORTS then we have multiple ports... Clear BOOTPORTS and get out
if defined BOOTPORTS if NOT "!BOOTPORTS: =!" == "!BOOTPORTS!" SET BOOTPORTS=&& goto BLDRDN 
rem If we found a boot port then get out with success
if defined BOOTPORTS goto BLDRDN
SET /A "x+=1"
rem if we haven't tried for 8 seconds -- retry again
if NOT "%x%"=="8" goto BLDR1
:BLDRDN
ENDLOCAL && SET BOOTLOADERPORT=%BOOTPORTS%
goto :EOF
rem 
rem 
rem ****************************************************************************
rem *                        Start of script execution                         *
rem ****************************************************************************
:START
SET EX=0
rem WAIT definitions:   WAIT=0Q (no wait prompts, no verbose from AVRDUDE),
rem                     WAIT=1q (no wait prompts,AVRDUDE output), 
rem                     WAIT=2  (Prompts and AVRDude output) 
SET WAIT=2
SET OPFLG=w&&       	rem this is 'r' to read or 'w' to write, 't' for term mode
SET DUDEHW=arduinoisp&& rem hardware to use (arduinoisp[default] or arduino or AVR109)
SET PROMICRO=AVR109&&   rem programmer type for ProMicro self programmming (/S)
SET FUSEST=0&&		rem fuse string after /F on cmd line
SET FSECTST=0&&		rem section name string after /M on cmd line
SET PORTST=#&&          rem port # read from cmdline
SET DEVICE=#&&          rem This is AVRDude device name (eg ATTiny25)
SET FILENAME=#&&	rem This is the file to program device with
SET DEBUG=0&&		rem if >0 then just show the command line (dont run AVRDude)
SET DOHELP=0&&		rem if >0 then show help screen
SET INFUSES=0
SET OVERWRITE=0&&	rem >0 to overwrite files that exist w/o asking
SET DUDEOPTS1=&&	rem AVRDude options before our parameters 
SET DUDEOPTS2=&&	rem AVRDude options After our parameters 
SET UNKNOWNPRM=&&	rem Unknown command line parameters
rem These are the modifiers for the file names for EEPROM and fuses
SET HEXEXT=.hex&&    	rem extension of flash and eeprom files
SET FUSEEXT=.txt&&   	rem extension of fuse files
SET EPROMSFX=_ep&&   	rem suffix of EEPROM file (extension is .hex)
SET FUSESFX=_f&&     	rem suffix of combined (and input/output) fuse file

rem *****   Pick parameters off the command line and put in variables   ********
SET TU=%1&&if NOT defined TU goto HELP
:CMDLINE
SET TU=%1
rem if %1 is empty then we're done -- get out
if NOT defined TU goto CMDLINEDONE
rem Convert all double quotes to  (DC2,0x12) so we can analyze them
rem ( is a character that normally won't appear on the cmdline) 
SET TV=%TU:"=%
rem If the variable is just a set of 2 dblquotes (now ) ignore them
if "%TV:=%" == "" echo EMPTY DBLQUOTES&& goto CMDLINENEXT
rem If begining and ending dblquotes exist, strip them (simulating %~1)
if NOT "%TV:~0,1%" =="" goto CMDLINE1
if NOT "%TV:~-1%" ==""  goto CMDLINE1
SET TV=%TV:~1%
SET TV=%TV:~0,-1%
:CMDLINE1
rem If parameter is just a bunch of spaces, ignore it
if "%TV: =%" == "" goto CMDLINENEXT
rem Count the number of dblquotes (now )
SET cnt2=0&&SET stc=%TV%&&CALL :COUNTCHARS 
rem If paramter format is '"xx' or 'xx"' or odd number of double quotes
if "%TV:~0,1%" =="" if NOT "%TV:~-1%" =="" goto CMDLINE2
if NOT "%TV:~0,1%" =="" if "%TV:~-1%" =="" goto CMDLINE2
if NOT "%cnt2%"=="0" goto CMDLINE2
rem Embedded quotes or even number of quotes -- Convert  back to quote
SET TU=%TV%&& rem Save copy of var with dblquotes changed to 
SET TV=%TV:="%
goto CMDLINE3
:CMDLINE2
rem Found an invalid parameter... Either '"xx' or 'xx"' or odd number of double quotes
rem echo This is an invalid parameter '%TV:="%'
SET EX=9
echo Invalid parameter (%TV:="%) found on command line. 
goto PROGRAMMINGDONE
rem goto CMDLINENEXT
:CMDLINE3
rem At this point we have parameters that won't make this batch file puke...
rem (NOTE: TV is parameter with dblquotes, TU is parameter without dblquotes)
rem Process it. 
rem echo PARAMETER IS '%TV%' (%TU%)
rem
rem If were working on fuses see if the next param starts with '0x' or '*'.
rem    If so, add it to FUSEST
if NOT %INFUSES%==1 goto NOTFUSEVAL
if /I "%TU:~0,2%"=="0X" SET FUSEST=%FUSEST%,%TU%&& goto CMDLINENEXT
if /I "%TU:~0,2%"=="*"  SET FUSEST=%FUSEST%,%TU%&& goto CMDLINENEXT
:NOTFUSEVAL
SET INFUSES=0
if    "%TU%"=="?"      SET DOHELP=1&&         goto CMDLINENEXT
rem If its a command line switch, interpret the letter
if /I NOT "%TU:~0,1%"=="/" goto PASTSWITCH
rem echo Got Switch '%TU%'
if /I "%TU:~1,1%"=="F" SET FUSEST=%TU:~2%&& SET INFUSES=1&&  goto CMDLINENEXT 
rem For all other switches, eliminate any spaces 
SET TU=%TU: =%
if    "%TU:~1,1%"=="Q" SET WAIT=0&&           goto CMDLINENEXT
if    "%TU:~1,1%"=="q" SET WAIT=1&&           goto CMDLINENEXT
if /I "%TU:~1,1%"=="R" SET OPFLG=r&&          goto CMDLINENEXT
if /I "%TU:~1,1%"=="T" SET OPFLG=t&&          goto CMDLINENEXT
if /I "%TU:~1,1%"=="P" SET PORTST=%TU:~2%&& SET DUDEHW=arduino&& goto CMDLINENEXT
if /I "%TU:~1,1%"=="S" SET PORTST=%TU:~2%&& SET DUDEHW=%PROMICRO%&&  goto CMDLINENEXT
if /I "%TU:~1,1%"=="O" SET OVERWRITE=1&&      goto CMDLINENEXT
if /I "%TU:~1,1%"=="H" SET DOHELP=1&&         goto CMDLINENEXT
if /I "%TU:~1,1%"=="?" SET DOHELP=1&&         goto CMDLINENEXT
if /I "%TU:~1,1%"=="X" SET DEBUG=1&&          goto CMDLINENEXT
if /I "%TU:~1,1%"=="M" SET FSECTST=%TU:~2%&&  goto CMDLINENEXT
rem If we haven't jumped out of here by now it's an invalid switch
goto CMDLINE2
:PASTSWITCH
rem If its an AVRDude option add it to either DUDEOPTS1 or DUDEOPTS2
rem Note: - is added at end of programming Dude cmds, -- is added before Dude cmds
if /I "%TU:~0,2%"=="--" (
if "%TU:~0,3%"=="--*" (SET DUDEOPTS1=%DUDEOPTS1% %TU:~3%) else (SET DUDEOPTS1=%DUDEOPTS1% %TV:~1%)
goto CMDLINENEXT 
)
if /I "%TU:~0,1%"=="-" (
if "%TU:~0,2%"=="-*" (SET DUDEOPTS2=%DUDEOPTS2% %TU:~2%) else (SET DUDEOPTS2=%DUDEOPTS2% %TV%)
goto CMDLINENEXT 
)
rem
rem else if param is not blank then put in DEVICE or FILENAME if not init'ed yet
if "%DEVICE%"=="#"   SET DEVICE=%TV%&&    goto CMDLINENEXT
if "%FILENAME%"=="#" SET FILENAME=%TV%&&  goto CMDLINENEXT
rem Not sure what to do with this parameter... add it to unknowns. 
SET UNKNOWNPRM=%UNKNOWNPRM% %TV%&&        goto CMDLINENEXT
:CMDLINENEXT
rem process the next cmdline parameter
SHIFT&&goto CMDLINE
:CMDLINEDONE
rem ***************   Done processing all command line parameters   ************
if NOT "%DUDEOPTS1%" == ""  SET DUDEOPTS1=%DUDEOPTS1:~1%
if NOT "%DUDEOPTS2%" == ""  SET DUDEOPTS2=%DUDEOPTS2:~1%
if NOT "%UNKNOWNPRM%" == "" SET UNKNOWNPRM=%UNKNOWNPRM:~1%
if "%UNKNOWNPRM%" == "" goto CMDLNDONE1
SET EX=8
echo Excess unknown parameter (%UNKNOWNPRM%) found on command line. 
goto PROGRAMMINGDONE
:CMDLNDONE1
SET EX=9
IF NOT "%DOHELP%"=="0" GOTO LONGHELP
rem
rem PORTST could be # (don't touch DUDEHW), or blank (use DUDEHW  -PDfltPort) 
rem or a value (use DUDEHW  -PPORTST)
if "%PORTST%"=="#" goto CMDLNDONE2
if "%PORTST%"=="" SET PORTST=%PORT%
SET DUDEHW=%DUDEHW% -P%PORTST%
if /I "%PORTST:~0,3%"=="COM" goto CMDLNDONE2
echo Error Port specified is not a comport (%PORTST%). 
SET PORTST=#
GOTO PROGRAMMINGDONE
:CMDLNDONE2
rem
rem **************** Check the parsed parameters *******************************
rem
rem ************* See that the DUDEPGM/CFG and file name are valid  ************
SET EX=8
IF NOT exist "%DUDEPGM%" ECHO AvrDude program not found.&& goto PROGRAMMINGDONE
SET EX=7
IF NOT exist "%DUDECFG%" ECHO AvrDude configuration file not found.&& goto PROGRAMMINGDONE
SET EX=6
if NOT "%DEVICE%" == "#" goto CMDLNDONE3
echo A device type (e.g. attiny85) must be specifed to use this program. 
:CMDLNDONEHELP
echo Type %SCRIPTNAME% /? for help
goto PROGRAMMINGDONE
:CMDLNDONE3
if "%FSECTST%"=="0" goto CMDLNDONE4
if defined FSECTST SET FSECTST=%FSECTST::=,%
if defined FSECTST SET FSECTST=%FSECTST: =%
if defined FSECTST SET FUSESECTS=%FSECTST%&& goto CMDLNDONE4
echo At least one fuse must be defined with /M command (eg /Mlfuse). 
goto PROGRAMMINGDONE
:CMDLNDONE4
rem Can't program fuses during a read or terminal operation
SET EX=5
IF NOT "%OPFLG%" == "w" if NOT "%FUSEST%" == "0"  echo Can't program fuses during a read or terminal operation (/F not allowed).&& goto PROGRAMMINGDONE
if NOT "%OPFLG%" == "t" goto PASTTERMINAL
rem 
rem ****************************************************************************
rem *****************   Run AVRDude Terminal mode if /T  ***********************
rem ****************************************************************************
if %DEBUG%==0 GOTO RUNTERMINAL
Echo Command line for AVRDude is:
Echo -C"%DUDECFG%" %DUDEOPTS1% -c%DUDEHW% -p%DEVICE%  -t %DUDEOPTS2%
SET EX=0
goto PROGRAMMINGDONE
:RUNTERMINAL
rem If its the promicro programmer then can't do terminal (it times out)
if NOT "%DUDEHW:~0,5%" == "%PROMICRO:~0,5%" goto RUNTERMINAL1
echo Can't run terminal mode for ProMicro (Catrina) programmer.
SET EX=5&&goto PROGRAMMINGDONE
:RUNTERMINAL1
echo:
echo Entering AVRDude Terminal mode (Type ? for AVRDude help or 'quit' to end).
"%DUDEPGM%" -C"%DUDECFG%" %DUDEOPTS1% -c%DUDEHW% -p%DEVICE%  -t %DUDEOPTS2%
SET EX=%ERRORLEVEL%
CALL :CKSETERRLITE
goto PROGRAMMINGDONE
:PASTTERMINAL
rem ****************************************************************************
rem *                        Done with terminal mode                           *
rem ****************************************************************************
rem
rem For all other operations a filename must exist. See if a filename was specified. 
SET EX=4
if NOT "%FILENAME%"=="#" goto HAVEFILENAME
echo A filename must be specifed to use this program. 
goto CMDLNDONEHELP
:HAVEFILENAME

rem Remove the '.hex' from the filename if it exists
SET FILENAME=%FILENAME:.HEX=%
rem Set NAMEONLY to name without path and PATHONLY to Path (without name)
for %%f in ("%FILENAME%") do set PATHONLY=%%~dpf
for %%f in ("%FILENAME%") do set NAMEONLY=%%~nf
rem 
rem ******************* Parse out the fuse section names ***********************
rem Create 'SECx' variables ('SECx' are the fuse section names for AVRDude) 
SET MAXSECS=6
rem Set section names to one space (don't "cleanup")
SET SEC1= && SET SEC2= && SET SEC3= && SET SEC4= && SET SEC5= && SET SEC6= 
FOR /f "tokens=1-%MAXSECS% delims=," %%a IN ("%FUSESECTS%") DO (
  if NOT "%%a"=="" SET SEC1=%%a
  if NOT "%%b"=="" SET SEC2=%%b
  if NOT "%%c"=="" SET SEC3=%%c
  if NOT "%%d"=="" SET SEC4=%%d
  if NOT "%%e"=="" SET SEC5=%%e
  if NOT "%%f"=="" SET SEC6=%%f
)
rem Remove any spaces from 'SECx' variables
SET SEC1=%SEC1: =%&& SET SEC2=%SEC2: =%&& SET SEC3=%SEC3: =%
SET SEC4=%SEC4: =%&& SET SEC5=%SEC5: =%&& SET SEC6=%SEC6: =%
rem echo Sections are '%SEC1%' '%SEC2%' '%SEC3%' '%SEC4%' '%SEC5%' '%SEC6%'
rem Determine how many fuse sections to use when reading or writing
SET NRSEC=0&&        rem number of fuses to read 
SET NWSEC=0&&        rem max number of fuses to write 
SET "x=1"&& SET "y=0"
:SECLOOP
  CALL SET name=%%SEC%x%%%
  if "%name%" == "" goto SECLOOPDONE
  SET NWSEC=%x%
  rem If the name starts with '*' dont allow NRSECTs to increment and 
  rem then remove the '*' from the section name
  if "%name:~0,1%" =="*" SET y=1&& CALL SET SEC%x%=%name:~1%
  if "%y%"=="0" SET NRSEC=%x%
  if [%x%] == [%MAXSECS%] goto SECLOOPDONE
  SET /a "x+=1"
  goto SECLOOP
:SECLOOPDONE
rem
rem ******************* See if filename exists *********************************
rem These are the AVRDude parameters for flash,eeprom and fuses
SET FLASHCMD=
SET EECMD=
SET FUSECMD=
if "%OPFLG%" == "w" goto CKWRITING
rem ****************************************************************************
rem *   Reading -- Verify files don't exist and create list of Dude params     *
rem ****************************************************************************
if /I "%FILENAME%" == "NUL" Echo Can't read part to file '%FILENAME%'&& goto PROGRAMMINGDONE
rem   Create list of files that will be deleted.
SET DELFILES=
if exist "%FILENAME%%HEXEXT%"           SET DELFILES=%NAMEONLY%%HEXEXT%
if exist "%FILENAME%%EPROMSFX%%HEXEXT%" SET DELFILES=%DELFILES%  %NAMEONLY%%EPROMSFX%%HEXEXT%
if exist "%FILENAME%%FUSESFX%%FUSEEXT%" SET DELFILES=%DELFILES%  %NAMEONLY%%FUSESFX%%FUSEEXT%
rem If not /O and files exist, ask if we should delete them
if NOT "%OVERWRITE%" == "0" GOTO CKREADOK
if "%DELFILES%" == ""       GOTO CKREADOK
rem Show path if user entered a path with the file name
If NOT "%FILENAME%" == "%FILENAME:\=%" echo File(s) in path: '%PATHONLY:~0,-1%'
rem Ask user if they want to delete files... get out if not
choice /m "File(s) %DELFILES% exist(s). Delete?"  
if %errorlevel% equ 2 echo Operation Aborted!&& goto PROGRAMMINGDONE
:CKREADOK
rem Setup FLASHCMD, EECMD and FUSECMD with parameter strings for AVRDUDE
SET FLASHCMD=-Uflash:%OPFLG%:"%FILENAME%%HEXEXT%":i
SET EECMD=-Ueeprom:%OPFLG%:"%FILENAME%%EPROMSFX%%HEXEXT%":i
SET "x=0"
:PFCADDLOOP
  if "%x%" == "6" goto CKREAD1
  SET /a "x+=1"
  CALL SET ss=%%SEC%x%%%
  if NOT defined ss goto CKREAD1
  CALL SET FUSECMD=%FUSECMD% -U%%SEC%x%%%:r:"%FILENAME%_%x%%FUSEEXT%":h
  if "%x%" == "%NRSEC%" goto CKREAD1
  goto PFCADDLOOP
:CKREAD1
if NOT defined FUSECMD goto CKDONE
if NOT "%FUSECMD:"=%" == ""  SET FUSECMD=%FUSECMD:~1%
GOTO CKDONE
rem ****************************************************************************
rem *   Programming -- Verify files do exist and prep FLASHCMD,EECMD,FUSECMD   *
rem ****************************************************************************
:CKWRITING
rem When writing at least one of the files (or FUSEST) must exist
IF /I "%FILENAME%" == "NUL"  GOTO PASTHEXFILES
if exist "%FILENAME%%HEXEXT%" goto GOTFILE
if exist "%FILENAME%%EPROMSFX%%HEXEXT%" goto GOTFILE
if exist "%FILENAME%%FUSESFX%%FUSEEXT%" goto GOTFILE
if NOT "%FUSEST%"=="0" goto GOTFILE
rem Show path if user entered a path with the file name
If NOT "%FILENAME%" == "%FILENAME:\=%" echo File(s) in path: '%PATHONLY:~0,-1%'
Echo Input file %NAMEONLY%%HEXEXT% (or %NAMEONLY%%EPROMSFX%%HEXEXT% or %NAMEONLY%%FUSESFXF%%FUSEEXT%) not found.&& goto PROGRAMMINGDONE
:GOTFILE
if exist "%FILENAME%%HEXEXT%" SET FLASHCMD=-Uflash:%OPFLG%:"%FILENAME%%HEXEXT%":i
if exist "%FILENAME%%EPROMSFX%%HEXEXT%" SET EECMD=-Ueeprom:%OPFLG%:"%FILENAME%%EPROMSFX%%HEXEXT%":i
:PASTHEXFILES
rem Now deal with fuses.   If file found read them.   If on cmdline add to list
SET FUSES=
SET FUSE1=*&& SET FUSE2=*&&SET FUSE3=*
SET FUSE4=*&& SET FUSE5=*&&SET FUSE6=*
rem Read fuses from the fuse file
if NOT exist "%FILENAME%%FUSESFX%%FUSEEXT%" goto FUSECMDLINE
for /f "tokens=* delims=" %%a in (
  'type "%FILENAME%%FUSESFX%%FUSEEXT%"') do (
   set FUSES=%%a& goto DONESF)
:DONESF
rem Assign fuses values to FUSE1,FUSE2,FUSE3 from FUSES
FOR /f "tokens=1-%MAXSECS% delims=," %%a IN ("%FUSES%") DO (
  if "%FUSE1%"=="*" if NOT "%%a"=="" SET FUSE1=%%a
  if "%FUSE2%"=="*" if NOT "%%b"=="" SET FUSE2=%%b
  if "%FUSE3%"=="*" if NOT "%%c"=="" SET FUSE3=%%c
  if "%FUSE4%"=="*" if NOT "%%d"=="" SET FUSE4=%%d
  if "%FUSE5%"=="*" if NOT "%%e"=="" SET FUSE5=%%e
  if "%FUSE6%"=="*" if NOT "%%f"=="" SET FUSE6=%%f
)
:FUSECMDLINE
rem If user entered ':' separators instead of ',' then change ':' to ','
if defined FUSEST SET FUSEST=%FUSEST::=,%
rem If the command line has a fuse setting, override the files fuse setting
FOR /f "tokens=1-%MAXSECS% delims=," %%a IN ("%FUSEST%") DO (
  if NOT "%%a"=="" if NOT "%%a"=="0" if NOT "%%a"=="*" SET FUSE1=%%a
  if NOT "%%b"=="" if NOT "%%b"=="*" SET FUSE2=%%b
  if NOT "%%c"=="" if NOT "%%c"=="*" SET FUSE3=%%c
  if NOT "%%d"=="" if NOT "%%d"=="*" SET FUSE4=%%d
  if NOT "%%e"=="" if NOT "%%e"=="*" SET FUSE5=%%e
  if NOT "%%f"=="" if NOT "%%f"=="*" SET FUSE6=%%f
)
rem Now build the AVRDude command line parameters for the fuses
SET "x=0"
:FCADDLOOP
  SET /a "x+=1"
  rem Get the value of FUSEx and SECx (call so token pasting occurs)
  CALL SET val=%%FUSE%x%%%
  CALL SET sec=%%SEC%x%%%
  rem eliminate spaces
  SET val=%val: =%
  rem if no section name or  'val' == '*' then skip this one
  if "%sec%"=="" goto FCSKIP
  if "%val%"=="*" goto FCSKIP
  if NOT "%val%"=="" CALL SET FUSECMD=%FUSECMD% -U%%SEC%x%%%:w:%val%:m
:FCSKIP
  if %x% GEQ %NWSEC% goto FCADDLOOPDONE
  goto FCADDLOOP
:FCADDLOOPDONE
if NOT "%FUSECMD%" == "" SET FUSECMD=%FUSECMD:~1%
rem
rem If there's no AVRDude commands to execute then tell user and be done. 
SET EX=3 
if defined FLASHCMD GOTO CKDONE
if defined EECMD GOTO CKDONE
if defined FUSECMD GOTO CKDONE
Echo Nothing specified to program. Exiting.
goto PROGRAMMINGDONE
:CKDONE

if %DEBUG%==0 GOTO PASTSPILLPARMS
echo:
echo Device= '%DEVICE%'  Filename='%FILENAME%' Fusest(cmdline)='%FUSEST%' 
echo DUDEHW = '%DUDEHW%' (%PORTST%)
echo DUDEOpt1= '%DUDEOPTS1%'   DUDEOpts2='%DUDEOPTS2%'   
echo Unknown= '%UNKNOWNPRM%'
echo Remaining Cmdline is  %1 %2 %3
echo Fuses are: '%FUSE1%,%FUSE2%,%FUSE3%,%FUSE4%,%FUSE5%' and FUSES(file) are '%FUSES%' 
echo Fuse Sect Names are: '%FUSESECTS%' 
echo:
echo DUDE CMDS are '%FLASHCMD%'  '%EECMD%'  '%FUSECMD%'
echo:
SET EX=0
rem goto PROGRAMMINGDONE
:PASTSPILLPARMS
rem
rem ******* Now pause before programming and set up dude quiet options   *******
rem
if "%WAIT%" == "2" IF "%OPFLG%" == "w" Echo Ready to program part with %FILENAME%%HEXEXT%  (Press ^^C to abort) && pause
SET DUDEQUIET=&& if %WAIT%==0 SET DUDEQUIET= -q -q
rem
rem ****************************************************************************
rem *                                                                          *
rem *                     Now run the avrdude program                          *
rem *                                                                          *
rem ****************************************************************************
if %DEBUG%==0 GOTO RUNDUDE
Echo:
Echo Command line for AVRDude is:
Echo "%DUDEPGM%" -C"%DUDECFG%" %DUDEQUIET% -c%DUDEHW% -p%DEVICE% %DUDEOPTS1% %FLASHCMD% %EECMD% %FUSECMD% %DUDEOPTS2% 
Echo:
SET EX=0
GOTO PROGRAMMINGDONE
:RUNDUDE
rem If its not the ProMicro programmer then skip findbootloader step
if NOT "%DUDEHW:~0,5%" == "%PROMICRO:~0,5%" goto RUNDUDE1
CALL :FINDBOOTLOADER %PORTST%
if NOT defined BOOTLOADERPORT SET EX=3&&echo Bootloader port not found&& goto PROGRAMMINGDONE
CALL SET DUDEHW=%%DUDEHW:%PORTST%=%BOOTLOADERPORT%%%
:RUNDUDE1
"%DUDEPGM%" -C"%DUDECFG%" %DUDEQUIET% -c%DUDEHW% -p%DEVICE% %DUDEOPTS1% %FLASHCMD% %EECMD% %FUSECMD% %DUDEOPTS2% 
SET EX=%ERRORLEVEL%
rem See if we need to turn on the error lite on the programmer
CALL :CKSETERRLITE
rem
rem ****************************************************************************
rem ******** Done executing AVRDude -- Process results if reading/needed *******
rem ****************************************************************************
rem
rem ************** if reading, combine the three fuse files into one ***********
:PROCESSFUSESREAD
rem If writing or error, skip post processing
if "%OPFLG%" == "w" goto PROCESSFUSESREADDONE
if not "%EX%"=="0"  goto PROCESSFUSESREADDONE 
rem Process all the fuse files into FUSE[1..5] (delete input files)
SET HAVEFUSE=0
FOR /L %%z IN (1,1,%MAXSECS%) DO (
  SET FUSE%%z= && rem leave space after %%z=
  if exist "%FILENAME%_%%z%FUSEEXT%" (
    for /f "tokens=* delims=" %%a in (
      'type "%FILENAME%_%%z%FUSEEXT%"') do (
       set FUSE%%z=%%a&&SET HAVEFUSE=%%z
       del "%FILENAME%_%%z%FUSEEXT%" 2> NUL
    )
  )
)
rem If we have no fuses -- be done
if "%HAVEFUSE%" == "0" goto PROCESSFUSESREADDONE
rem Build a "FUSES" variable that has all the fuses in it
SET FUSES=&& SET "x=1"
:PFUSEADDLOOP
if defined FUSE%x% (
  CALL SET FUSES=%FUSES%,%%FUSE%x%%%
  SET /a "x+=1"
  if [%HAVEFUSE%] == [%x%] goto PFLOOPDONE 
  goto PFUSEADDLOOP
)
:PFLOOPDONE
rem Remove the initial comma
if NOT "%FUSES%" == "" SET FUSES=%FUSES:~1%
if NOT "%DEBUG%"=="0"  echo Writing %HAVEFUSE% Fuses (%FUSES%) to  %FILENAME%%FUSESFX%%FUSEEXT%
rem Write it to the file
echo %FUSES% > "%FILENAME%%FUSESFX%%FUSEEXT%"
:PROCESSFUSESREADDONE

rem ****************************************************************************
rem *									       *
rem *                Done with the programming / reading cycle                 *
rem *									       *
rem ****************************************************************************
:PROGRAMMINGDONE
SET FNAME=programming part
if "%OPFLG%" == "r" SET FNAME=reading part
if "%OPFLG%" == "t" SET FNAME=in terminal mode
if NOT %EX% == 0  Echo Error %FNAME% !! (Err=%EX%) && GOTO DONE
SET FNAME=programmed
if "%OPFLG%" == "r" SET FNAME=read
if "%OPFLG%" == "t" goto DONE
if "%WAIT%" == "0" goto DONE
Echo Part %FNAME% successfully. 
:DONE
if NOT "%EX%" == "0" GOTO DOPAUSE
if NOT "%WAIT%" == "2" GOTO DONE2
:DOPAUSE
pause
:DONE2
Exit /B %EX%
