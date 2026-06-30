@echo off

set "CFG=%~dp0copyipconfig.txt"
set "TMP=%TEMP%\copyipconfig_vars.txt"

:menu
echo.
echo [1] Save aktuelle IP-Konfiguration
echo [2] Restore gespeicherte IP-Konfiguration
echo.
set /p "CHOICE=Auswahl: "

if "%CHOICE%"=="1" goto save
if "%CHOICE%"=="2" goto restore

echo Ungueltige Auswahl.
goto end


:save
set "IFACE="
set "MAC="
set "IP="
set "PREFIX="
set "GATEWAY="
set "DNS="

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=@(Get-NetIPConfiguration | ? {$_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up'}); if($c.Count -eq 0){Write-Host 'Kein aktives Interface gefunden.'; exit}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($i=0;$i -lt $c.Count;$i++){Write-Host ('['+($i+1)+'] '+$c[$i].InterfaceAlias+' IP '+$c[$i].IPv4Address.IPAddress+' GW '+$c[$i].IPv4DefaultGateway.NextHop)}; $s=[int](Read-Host 'Nummer'); if($s -lt 1 -or $s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit}; $c=$c[$s-1]} else {$c=$c[0]}; $i=$c.InterfaceIndex; $a=Get-NetAdapter -InterfaceIndex $i; $d=(Get-DnsClientServerAddress -InterfaceIndex $i -AddressFamily IPv4).ServerAddresses; Write-Output ('IFACE='+$c.InterfaceAlias); Write-Output ('MAC='+$a.MacAddress); Write-Output ('IP='+$c.IPv4Address.IPAddress); Write-Output ('PREFIX='+$c.IPv4Address.PrefixLength); Write-Output ('GATEWAY='+$c.IPv4DefaultGateway.NextHop); Write-Output ('DNS='+($d -join ';'))" > "%TMP%"

for /f "usebackq tokens=1,* delims==" %%A in ("%TMP%") do set "%%A=%%B"

if not defined IP (
    echo Es wurde nichts gespeichert.
    goto end
)

type nul > "%CFG%"
echo(%IFACE%>>"%CFG%"
echo(%MAC%>>"%CFG%"
echo(%IP%>>"%CFG%"
echo(%PREFIX%>>"%CFG%"
echo(%GATEWAY%>>"%CFG%"
echo(%DNS%>>"%CFG%"

echo.
echo Gespeichert in:
echo %CFG%
goto end


:restore
if not exist "%CFG%" (
    echo Datei nicht gefunden:
    echo %CFG%
    goto end
)

< "%CFG%" (
set /p rIFACE=
set /p rMAC=
set /p rIP=
set /p rPREFIX=
set /p rGATEWAY=
set /p rDNS=
)

if not defined rIP (
    echo Gespeicherte Datei ist ungueltig oder leer.
    goto end
)

echo.
echo Gespeicherte Werte:
echo IFACE=%rIFACE%
echo MAC=%rMAC%
echo IP=%rIP%
echo PREFIX=%rPREFIX%
echo GATEWAY=%rGATEWAY%
echo DNS=%rDNS%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=@(Get-NetIPConfiguration | ? {$_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up'}); if($c.Count -eq 0){Write-Host 'Kein aktives Interface gefunden.'; exit}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($i=0;$i -lt $c.Count;$i++){Write-Host ('['+($i+1)+'] '+$c[$i].InterfaceAlias+' IP '+$c[$i].IPv4Address.IPAddress+' GW '+$c[$i].IPv4DefaultGateway.NextHop)}; $s=[int](Read-Host 'Nummer fuer Restore'); if($s -lt 1 -or $s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit}; $c=$c[$s-1]} else {$c=$c[0]}; $n=$c.InterfaceAlias; Write-Host ('Restore auf Interface: '+$n); Set-NetIPInterface -InterfaceAlias $n -AddressFamily IPv4 -Dhcp Disabled; Remove-NetIPAddress -InterfaceAlias $n -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; New-NetIPAddress -InterfaceAlias $n -IPAddress $env:rIP -PrefixLength $env:rPREFIX -DefaultGateway $env:rGATEWAY; Set-DnsClientServerAddress -InterfaceAlias $n -ServerAddresses ($env:rDNS -split ';')"

goto end


:end
pause
