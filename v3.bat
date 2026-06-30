@echo off
setlocal EnableExtensions

set "CFG=%~dp0copyipconfig.txt"
set "TMP=%TEMP%\copyipconfig_%RANDOM%.tmp"

:menu
cls
echo [1] Save
echo [2] Restore
echo [3] View copyipconfig.txt
echo [Q] Quite
echo.
set /p "CHOICE=Auswahl: "

if /i "%CHOICE%"=="1" goto save
if /i "%CHOICE%"=="2" goto restore
if /i "%CHOICE%"=="3" goto view
if /i "%CHOICE%"=="Q" goto quit

echo Ungueltige Auswahl.
pause
goto menu


:save
set "IFACE="
set "MAC="
set "IP="
set "PREFIX="
set "GATEWAY="
set "DNS="

if exist "%TMP%" del "%TMP%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=@(Get-NetIPConfiguration | ? {$_.IPv4Address -and (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex).Status -eq 'Up'}); if($c.Count -eq 0){Write-Host 'Kein aktives Interface mit IPv4 gefunden.'; exit 1}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($x=0;$x -lt $c.Count;$x++){$a=Get-NetAdapter -InterfaceIndex $c[$x].InterfaceIndex; $ip=@($c[$x].IPv4Address.IPAddress)-join ';'; $gw=@($c[$x].IPv4DefaultGateway.NextHop)-join ';'; Write-Host ('['+($x+1)+'] '+$c[$x].InterfaceAlias+' | '+$a.MacAddress+' | IP='+$ip+' | GW='+$gw)}; $s=Read-Host 'Nummer'; if(-not ($s -as [int]) -or [int]$s -lt 1 -or [int]$s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit 1}; $c=$c[[int]$s-1]}else{$c=$c[0]}; $i=$c.InterfaceIndex; $a=Get-NetAdapter -InterfaceIndex $i; $d=@((Get-DnsClientServerAddress -InterfaceIndex $i -AddressFamily IPv4).ServerAddresses); $v4=@($c.IPv4Address); $gw=@($c.IPv4DefaultGateway | ? {$_.NextHop}); 'IFACE='+$c.InterfaceAlias; 'MAC='+$a.MacAddress; 'IP='+($v4.IPAddress -join ';'); 'PREFIX='+($v4.PrefixLength -join ';'); 'GATEWAY='+($gw.NextHop -join ';'); 'DNS='+($d -join ';')" > "%TMP%"

if errorlevel 1 (
    pause
    goto menu
)

for /f "usebackq tokens=1,* delims==" %%A in ("%TMP%") do set "%%A=%%B"

if not defined IP (
    echo Es wurde nichts gespeichert.
    pause
    goto menu
)

type nul > "%CFG%"
echo(IFACE=%IFACE%>>"%CFG%"
echo(MAC=%MAC%>>"%CFG%"
echo(IP=%IP%>>"%CFG%"
echo(PREFIX=%PREFIX%>>"%CFG%"
echo(GATEWAY=%GATEWAY%>>"%CFG%"
echo(DNS=%DNS%>>"%CFG%"

echo.
echo Gespeichert:
echo %CFG%
pause
goto menu


:restore
if not exist "%CFG%" (
    echo Datei nicht gefunden:
    echo %CFG%
    pause
    goto menu
)

set "rIFACE="
set "rMAC="
set "rIP="
set "rPREFIX="
set "rGATEWAY="
set "rDNS="

for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do set "r%%A=%%B"

echo.
echo Geladene Werte:
echo IFACE=%rIFACE%
echo MAC=%rMAC%
echo IP=%rIP%
echo PREFIX=%rPREFIX%
echo GATEWAY=%rGATEWAY%
echo DNS=%rDNS%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){Write-Host 'Restore braucht Administratorrechte.'; exit 1}; $c=@(Get-NetIPConfiguration | ? {$_.IPv4Address -and (Get-NetAdapter -InterfaceIndex $_.InterfaceIndex).Status -eq 'Up'}); if($c.Count -eq 0){Write-Host 'Kein aktives Interface mit IPv4 gefunden.'; exit 1}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($x=0;$x -lt $c.Count;$x++){$a=Get-NetAdapter -InterfaceIndex $c[$x].InterfaceIndex; $ip=@($c[$x].IPv4Address.IPAddress)-join ';'; $gw=@($c[$x].IPv4DefaultGateway.NextHop)-join ';'; Write-Host ('['+($x+1)+'] '+$c[$x].InterfaceAlias+' | '+$a.MacAddress+' | IP='+$ip+' | GW='+$gw)}; $s=Read-Host 'Nummer fuer Restore'; if(-not ($s -as [int]) -or [int]$s -lt 1 -or [int]$s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit 1}; $c=$c[[int]$s-1]}else{$c=$c[0]}; $n=$c.InterfaceAlias; $ips=@($env:rIP -split ';' | ? {$_}); $pre=@($env:rPREFIX -split ';' | ? {$_}); $gw=@($env:rGATEWAY -split ';' | ? {$_}); $dns=@($env:rDNS -split ';' | ? {$_}); Write-Host ('Restore auf Interface: '+$n); if($ips.Count -gt 0 -and $pre.Count -gt 0){Set-NetIPInterface -InterfaceAlias $n -AddressFamily IPv4 -Dhcp Disabled; Remove-NetIPAddress -InterfaceAlias $n -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; for($x=0;$x -lt $ips.Count;$x++){$prefix=[int]$pre[[Math]::Min($x,$pre.Count-1)]; if($x -eq 0 -and $gw.Count -gt 0){New-NetIPAddress -InterfaceAlias $n -IPAddress $ips[$x] -PrefixLength $prefix -DefaultGateway $gw[0]}else{New-NetIPAddress -InterfaceAlias $n -IPAddress $ips[$x] -PrefixLength $prefix}}}else{Write-Host 'Keine IP/PREFIX gespeichert, IPv4 wird auf DHCP gesetzt.'; Set-NetIPInterface -InterfaceAlias $n -AddressFamily IPv4 -Dhcp Enabled}; if($dns.Count -gt 0){Set-DnsClientServerAddress -InterfaceAlias $n -ServerAddresses $dns}else{Set-DnsClientServerAddress -InterfaceAlias $n -ResetServerAddresses}"

pause
goto menu


:view
cls
if exist "%CFG%" (
    type "%CFG%"
) else (
    echo copyipconfig.txt nicht gefunden:
    echo %CFG%
)
echo.
pause
goto menu


:quit
if exist "%TMP%" del "%TMP%" >nul 2>&1
exit /b
