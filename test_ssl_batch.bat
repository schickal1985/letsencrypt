@echo off
setlocal
chcp 65001 >nul

:START
echo ===================================================
echo        SSL ZERTIFIKAT LIVE-TESTER
echo ===================================================
echo.
set /p domain="Gib die zu pruefende Domain ein (z.B. energetikologie.at): "

echo.
echo [1/2] LOKALE GEGENPRUEFUNG (Dein Computer) ...
powershell -Command "$ErrorActionPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $req = [Net.HttpWebRequest]::Create('https://%domain%'); $req.Timeout = 5000; $response = $req.GetResponse(); if($?) { $cert = $req.ServicePoint.Certificate; $certObj = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert); Write-Host '  -> VERBUNDEN! Gueltig bis: ' $certObj.NotAfter -ForegroundColor Green; $response.Close() } else { Write-Host '  -> FEHLER: Lokal nicht abrufbar!' -ForegroundColor Red }"

echo.
echo [2/2] WELTWEITE GEGENPRUEFUNG (Ueber externe Server) ...
echo HINWEIS: Bei neuen Zertifikaten kann es bis zu 48h dauern, bis diese in der API (CertSpotter) sichtbar sind!
powershell -Command "$ErrorActionPreference = 'SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $apiUrl = 'https://api.certspotter.com/v1/issuances?domain=' + '%domain%' + '&include_subdomains=true&expand=dns_names&expand=issuer'; $response = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 10; if ($response) { $latestCert = $response[0]; Write-Host '  -> GLOBAL BESTAETIGT! Letzte Ausstellung:' (Get-Date $latestCert.not_before).ToString('dd.MM.yyyy HH:mm:ss') -ForegroundColor Green; Write-Host '  -> Gueltig fuer : ' ($latestCert.dns_names -join ', ') -ForegroundColor Cyan } else { Write-Host '  -> WARNUNG: Kein kuerzlich ausgestelltes Zertifikat in der globalen Datenbank gefunden!' -ForegroundColor Yellow }"

echo ---------------------------------------------------

echo.
echo 1 - Weitere Domain pruefen
echo 2 - Alles erledigt (Beenden)
set /p choice="Waehle eine Option [1-2]: "
if "%choice%"=="1" (
    cls
    goto START
) else (
    exit
)
