@echo off

if "%~1"=="-s" goto save
if "%~1"=="-r" goto restore
echo -s=save -r=restore
goto end

:save
type nul > "copyipconfig.txt"
for /f "tokens=1,* delims==" %%A in ('powershell -NoProfile -Command "$c=@(Get-NetIPConfiguration | ? {$_.IPv4Address -and $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up'}); if($c.Count -ne 1){exit}; $c=$c[0]; $i=$c.InterfaceIndex; $a=Get-NetAdapter -InterfaceIndex $i; $d=(Get-DnsClientServerAddress -InterfaceIndex $i -AddressFamily IPv4).ServerAddresses; 'IFACE='+$c.InterfaceAlias; 'MAC='+$a.MacAddress; 'IP='+$c.IPv4Address.IPAddress; 'PREFIX='+$c.IPv4Address.PrefixLength; 'GATEWAY='+$c.IPv4DefaultGateway.NextHop; 'DNS='+($d -join ';')"') do set "%%A=%%B"
echo %IFACE% >> "copyipconfig.txt"
echo %MAC% >> "copyipconfig.txt"
echo %IP% >> "copyipconfig.txt"
echo %PREFIX% >> "copyipconfig.txt"
echo %GATEWAY% >> "copyipconfig.txt"
echo %DNS% >> "copyipconfig.txt"
:goto end

:restore
< copyipconfig.txt (
set /p rIFACE=
set /p rMAC=
set /p rIP=
set /p rPREFIX=
set /p rGATEWAY=
set /p rDNS=
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=Get-NetAdapter | ? {$_.MacAddress -eq '%rMAC%'}; if(@($a).Count -ne 1){exit}; $n=$a.Name; Set-NetIPInterface -InterfaceAlias $n -AddressFamily IPv4 -Dhcp Disabled; Remove-NetIPAddress -InterfaceAlias $n -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue; New-NetIPAddress -InterfaceAlias $n -IPAddress '%rIP%' -PrefixLength %rPREFIX% -DefaultGateway '%rGATEWAY%'; Set-DnsClientServerAddress -InterfaceAlias $n -ServerAddresses ('%rDNS%' -split ';')"

:end
pause
