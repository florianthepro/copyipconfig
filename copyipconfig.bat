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
set "IP_MODE="
set "IP="
set "PREFIX="
set "GATEWAY="
set "DNS_MODE="
set "DNS="

if exist "%TMP%" del "%TMP%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command "$c=@(); foreach($a in Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'}){$x=Get-NetIPConfiguration -InterfaceIndex $a.InterfaceIndex; if($x.IPv4Address -and $x.IPv4DefaultGateway){$c+=$x}}; if($c.Count -eq 0){Write-Host 'Kein aktives Interface mit IPv4-Gateway gefunden.'; exit 1}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($i=0;$i -lt $c.Count;$i++){$a=Get-NetAdapter -InterfaceIndex $c[$i].InterfaceIndex; $ip=@($c[$i].IPv4Address.IPAddress)-join ';'; $gw=@($c[$i].IPv4DefaultGateway.NextHop)-join ';'; Write-Host ('['+($i+1)+'] '+$c[$i].InterfaceAlias+' | IP='+$ip+' | GW='+$gw)}; $s=Read-Host 'Nummer'; if(-not ($s -as [int]) -or [int]$s -lt 1 -or [int]$s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit 1}; $c=$c[[int]$s-1]}else{$c=$c[0]}; $idx=$c.InterfaceIndex; $a=Get-NetAdapter -InterfaceIndex $idx; $ni=Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4; $ipmode=if($ni.Dhcp -eq 'Enabled'){'DHCP'}else{'STATIC'}; $reg='HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\'+$a.InterfaceGuid.ToString(); $ns=(Get-ItemProperty -Path $reg -Name NameServer -ErrorAction SilentlyContinue).NameServer; $dnsmode=if($ns){'STATIC'}else{'AUTO'}; if($ipmode -eq 'DHCP'){$ip='';$prefix='';$gateway=''}else{$ip=@($c.IPv4Address.IPAddress)-join ';'; $prefix=@($c.IPv4Address.PrefixLength)-join ';'; $gateway=@($c.IPv4DefaultGateway.NextHop)-join ';'}; if($dnsmode -eq 'STATIC'){$dns=@((Get-DnsClientServerAddress -InterfaceIndex $idx -AddressFamily IPv4).ServerAddresses)-join ';'}else{$dns=''}; 'IP_MODE='+$ipmode; 'IP='+$ip; 'PREFIX='+$prefix; 'GATEWAY='+$gateway; 'DNS_MODE='+$dnsmode; 'DNS='+$dns" > "%TMP%"

if errorlevel 1 (
    pause
    goto menu
)

for /f "usebackq tokens=1,* delims==" %%A in ("%TMP%") do set "%%A=%%B"

type nul > "%CFG%"
echo(IP_MODE=%IP_MODE%>>"%CFG%"
echo(IP=%IP%>>"%CFG%"
echo(PREFIX=%PREFIX%>>"%CFG%"
echo(GATEWAY=%GATEWAY%>>"%CFG%"
echo(DNS_MODE=%DNS_MODE%>>"%CFG%"
echo(DNS=%DNS%>>"%CFG%"

echo.
echo Gespeichert.
pause
goto menu


:restore
if not exist "%CFG%" (
    echo copyipconfig.txt nicht gefunden.
    pause
    goto menu
)

set "rIP_MODE="
set "rIP="
set "rPREFIX="
set "rGATEWAY="
set "rDNS_MODE="
set "rDNS="

for /f "usebackq tokens=1,* delims==" %%A in ("%CFG%") do set "r%%A=%%B"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent()); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){Write-Host 'Restore braucht Administratorrechte.'; exit 1}; $c=@(); foreach($a in Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'}){$x=Get-NetIPConfiguration -InterfaceIndex $a.InterfaceIndex; if($x.IPv4Address -and $x.IPv4DefaultGateway){$c+=$x}}; if($c.Count -eq 0){Write-Host 'Kein aktives Interface mit IPv4-Gateway gefunden.'; exit 1}; if($c.Count -gt 1){Write-Host 'Mehrere aktive Interfaces gefunden:'; for($i=0;$i -lt $c.Count;$i++){$ip=@($c[$i].IPv4Address.IPAddress)-join ';'; $gw=@($c[$i].IPv4DefaultGateway.NextHop)-join ';'; Write-Host ('['+($i+1)+'] '+$c[$i].InterfaceAlias+' | IP='+$ip+' | GW='+$gw)}; $s=Read-Host 'Nummer fuer Restore'; if(-not ($s -as [int]) -or [int]$s -lt 1 -or [int]$s -gt $c.Count){Write-Host 'Ungueltige Auswahl.'; exit 1}; $c=$c[[int]$s-1]}else{$c=$c[0]}; $n=$c.InterfaceAlias; Write-Host ('Restore auf Interface: '+$n); function Mask($p){$x=[int]$p; $b=0..3 | ForEach-Object { if($x -ge 8){$x-=8;255}elseif($x -gt 0){$v=256-[math]::Pow(2,8-$x);$x=0;[int]$v}else{0} }; $b -join '.'}; if($env:rIP_MODE -eq 'DHCP'){netsh interface ipv4 set address name=\"$n\" source=dhcp | Out-Null}else{$ips=@($env:rIP -split ';' | Where-Object {$_}); $pre=@($env:rPREFIX -split ';' | Where-Object {$_}); $gw=@($env:rGATEWAY -split ';' | Where-Object {$_}); if($ips.Count -gt 0 -and $pre.Count -gt 0){$mask=Mask $pre[0]; if($gw.Count -gt 0){netsh interface ipv4 set address name=\"$n\" source=static address=$ips[0] mask=$mask gateway=$gw[0] | Out-Null}else{netsh interface ipv4 set address name=\"$n\" source=static address=$ips[0] mask=$mask gateway=none | Out-Null}}else{Write-Host 'Keine statische IP gespeichert.'}}; if($env:rDNS_MODE -eq 'AUTO'){netsh interface ipv4 set dnsservers name=\"$n\" source=dhcp | Out-Null}else{$dns=@($env:rDNS -split ';' | Where-Object {$_}); if($dns.Count -gt 0){netsh interface ipv4 set dnsservers name=\"$n\" source=static address=$dns[0] register=primary validate=no | Out-Null; for($i=1;$i -lt $dns.Count;$i++){netsh interface ipv4 add dnsservers name=\"$n\" address=$dns[$i] index=($i+1) validate=no | Out-Null}}else{netsh interface ipv4 set dnsservers name=\"$n\" source=dhcp | Out-Null}}"

pause
goto menu


:view
cls
echo copyipconfig.txt:
echo.

if exist "%CFG%" (
    type "%CFG%"
) else (
    echo Datei nicht gefunden:
    echo %CFG%
)

echo.
pause
goto menu


:quit
if exist "%TMP%" del "%TMP%" >nul 2>&1
exit /b
