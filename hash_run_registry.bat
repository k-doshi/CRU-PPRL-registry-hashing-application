@echo off
SETLOCAL ENABLEEXTENSIONS

for /F "eol=; tokens=1* delims==" %%i in (config.txt) do set %%i=%%j
set Credentials=-U %Username% -P %Password%
if %Username%==. set Credentials=-E
set t=%date%_%time%
set d=%t:~10,4%%t:~7,2%%t:~4,2%_%t:~15,2%%t:~18,2%%t:~21,2%

sqlcmd -b -S %Server% -d %Database% %Credentials% %Crypt% -s, -W -i ".\SQLFiles\InsertintoHash.sql" -o ".\Log\InsertLog_Temp.txt"
if "%errorlevel%" == "1" goto err_handler
goto success 

:err_handler
echo Insert failed with error #%errorlevel% >> ".\Log\InsertError_%d%.txt"
SET /p delExit=Insert to sql table failed, review log files for more details. Press the ENTER key to exit...:
exit /b

:success
for /F "tokens=*"  %%i in ('type ".\Log\InsertLog_Temp.txt" ^| findstr /i "record"') do (
>> ".\Log\InsertTableLog_%d%.txt" echo %%i)
set count=0
for /f "tokens=*" %%r in ('type ".\Log\InsertLog_Temp.txt" ^| findstr /i "row affected"') do (
for /f "tokens=1 delims=^( " %%c in ("%%r") do set /a count=%%c
)
echo %count% records hashed and inserted into the table successfully >> ".\Log\InsertTableLog_%d%.txt"
del ".\Log\InsertLog_Temp.txt"
SET /p delExit=Completed successfully, review log files for more details. Press the ENTER key to exit...:
exit /b
