param(
    [int]$DurationMinutes = 60,
    [int]$BaselineMbps = 300,
    [int]$Streams = 16,
    [string]$Portal = "",
    [string]$DeviceLabel = "windows-device",
    [string]$DownloadUrl = "https://ash-speed.hetzner.com/100MB.bin",
    [int]$CurlMaxTime = 300
)

$IntervalSeconds = 120
$SaasUrl = "https://login.salesforce.com"
$PingTarget = "zoom.us"
$MinValidBytes = 1000000

$DirectLog = "${DeviceLabel}_direct_${Streams}_streams_${DurationMinutes}min.csv"
$PrismaAccessLog = "${DeviceLabel}_prisma_access_${Streams}_streams_${DurationMinutes}min.csv"

$GpCliPaths = @(
    "C:\Program Files\Palo Alto Networks\GlobalProtect\globalprotect.exe",
    "C:\Program Files\Palo Alto Networks\GlobalProtect\PanGPA.exe"
)

$GpCli = $GpCliPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

function Write-HeaderIfNeeded {
    param([string]$LogFile)

    if (!(Test-Path $LogFile)) {
        "Timestamp,Device_Label,Path_Label,Egress_IP,Download_URL,Streams_Requested,Single_HTTP,Single_Bytes,Single_Time_sec,Single_Mbps,Multi_Streams_Successful,Multi_Bytes,Multi_Time_sec,Multi_Mbps,Efficiency_%,SaaS_URL,SaaS_TTFB_sec,Ping_Target,Latency_Avg_ms,Packet_Loss_%,GP_Status" | Out-File -FilePath $LogFile -Encoding utf8
    }
}

function Get-GPStatus {
    if (!$GpCli) {
        return "GlobalProtect CLI not found"
    }

    try {
        $p = Start-Process -FilePath $GpCli -ArgumentList "show --status" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\gp_status.out" -RedirectStandardError "$env:TEMP\gp_status.err"
        if (!$p.WaitForExit(5000)) {
            $p.Kill()
            return "status_timeout"
        }

        return ((Get-Content "$env:TEMP\gp_status.out" -ErrorAction SilentlyContinue) -join " ") -replace ",", ";"
    }
    catch {
        return "status_error"
    }
}

function Disconnect-GP {
    if (!$GpCli) {
        Write-Host "GlobalProtect CLI not found. Skipping disconnect."
        return
    }

    Write-Host "Disconnecting GlobalProtect..."

    try {
        $p = Start-Process -FilePath $GpCli -ArgumentList 'disconnect --reason "performance testing"' -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\gp_disconnect.out" -RedirectStandardError "$env:TEMP\gp_disconnect.err"
        if (!$p.WaitForExit(30000)) {
            Write-Host "GlobalProtect disconnect command still running; continuing."
            $p.Kill()
        }
    }
    catch {
        Write-Host "GlobalProtect disconnect failed or is unsupported on this client."
    }

    Start-Sleep -Seconds 20
    Write-Host "GP status after disconnect: $(Get-GPStatus)"
}

function Connect-GP {
    if (!$GpCli) {
        Write-Host "GlobalProtect CLI not found. Skipping connect."
        return
    }

    if ([string]::IsNullOrWhiteSpace($Portal)) {
        Write-Host "No GlobalProtect portal provided. Skipping connect."
        return
    }

    Write-Host "Connecting GlobalProtect to portal: $Portal"

    try {
        $p = Start-Process -FilePath $GpCli -ArgumentList "connect --portal $Portal" -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\gp_connect.out" -RedirectStandardError "$env:TEMP\gp_connect.err"
        if (!$p.WaitForExit(60000)) {
            Write-Host "GlobalProtect connect command still running; continuing."
            $p.Kill()
        }
    }
    catch {
        Write-Host "GlobalProtect connect failed or requires interactive login."
    }

    Start-Sleep -Seconds 30
    Write-Host "GP status after connect: $(Get-GPStatus)"
}

function Get-EgressIP {
    try {
        return (Invoke-RestMethod -Uri "https://ifconfig.me" -TimeoutSec 10)
    }
    catch {
        return "unknown"
    }
}

function Run-OneSample {
    param(
        [string]$PathLabel,
        [string]$LogFile
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$Timestamp] Running $PathLabel sample..."

    $GpStatus = Get-GPStatus
    $EgressIP = Get-EgressIP

    $SingleOutput = & curl.exe -L --connect-timeout 10 --max-time $CurlMaxTime -o NUL -sS -w "%{http_code},%{speed_download},%{size_download},%{time_total}" $DownloadUrl 2>$null
    $SingleParts = $SingleOutput -split ","

    $SingleHttp = $SingleParts[0]
    $SingleBps = [double]$SingleParts[1]
    $SingleBytes = [double]$SingleParts[2]
    $SingleTime = [double]$SingleParts[3]

    if ($SingleHttp -ne "200" -or $SingleBytes -lt $MinValidBytes) {
        $SingleMbps = 0
    }
    else {
        $SingleMbps = [math]::Round(($SingleBps * 8) / 1000000, 2)
    }

    $StartTime = Get-Date
    $Jobs = @()

    for ($i = 1; $i -le $Streams; $i++) {
        $Jobs += Start-Job -ScriptBlock {
            param($Url, $Timeout)
            & curl.exe -L --connect-timeout 10 --max-time $Timeout -o NUL -s -w "%{http_code},%{size_download},%{time_total}" $Url 2>$null
        } -ArgumentList $DownloadUrl, $CurlMaxTime
    }

    Wait-Job $Jobs | Out-Null
    $EndTime = Get-Date

    $MultiTime = [math]::Round(($EndTime - $StartTime).TotalSeconds, 3)
    $MultiSuccess = 0
    $MultiBytes = 0

    foreach ($Job in $Jobs) {
        $Result = Receive-Job $Job
        Remove-Job $Job

        $Parts = $Result -split ","
        if ($Parts.Count -ge 2) {
            $Http = $Parts[0]
            $Bytes = [double]$Parts[1]

            if ($Http -eq "200" -and $Bytes -ge $MinValidBytes) {
                $MultiSuccess++
                $MultiBytes += $Bytes
            }
        }
    }

    if ($MultiSuccess -eq 0 -or $MultiTime -eq 0) {
        $MultiMbps = 0
        $Efficiency = 0
    }
    else {
        $MultiMbps = [math]::Round(($MultiBytes * 8) / ($MultiTime * 1000000), 2)
        $Efficiency = [math]::Round(($MultiMbps / $BaselineMbps) * 100, 1)
    }

    $Ttfb = & curl.exe -L --connect-timeout 10 --max-time 30 -sS -o NUL -w "%{time_starttransfer}" $SaasUrl 2>$null
    if ([string]::IsNullOrWhiteSpace($Ttfb)) {
        $Ttfb = 0
    }

    try {
        $Ping = Test-Connection -ComputerName $PingTarget -Count 10 -ErrorAction Stop
        $Latency = [math]::Round(($Ping | Measure-Object -Property ResponseTime -Average).Average, 2)
        $Loss = 0
    }
    catch {
        $Latency = 0
        $Loss = 100
    }

    "$Timestamp,$DeviceLabel,$PathLabel,$EgressIP,$DownloadUrl,$Streams,$SingleHttp,$SingleBytes,$SingleTime,$SingleMbps,$MultiSuccess,$MultiBytes,$MultiTime,$MultiMbps,$Efficiency,$SaasUrl,$Ttfb,$PingTarget,$Latency,$Loss,$GpStatus" | Out-File -FilePath $LogFile -Append -Encoding utf8

    Write-Host "  -> Device        : $DeviceLabel"
    Write-Host "  -> Path          : $PathLabel"
    Write-Host "  -> Egress IP     : $EgressIP"
    Write-Host "  -> Single Stream : $SingleMbps Mbps"
    Write-Host "  -> Multi Stream  : $MultiMbps Mbps using $MultiSuccess/$Streams streams"
    Write-Host "  -> SaaS TTFB     : $Ttfb s"
    Write-Host "  -> Latency       : $Latency ms Loss=$Loss%"
    Write-Host "------------------------------------------------------------------------"
}

function Run-Phase {
    param(
        [string]$PathLabel,
        [string]$LogFile
    )

    Write-HeaderIfNeeded $LogFile

    $EndTime = (Get-Date).AddMinutes($DurationMinutes)

    Write-Host "Starting $PathLabel phase for $DurationMinutes minutes."
    Write-Host "Log file: $LogFile"
    Write-Host "------------------------------------------------------------------------"

    while ((Get-Date) -lt $EndTime) {
        Run-OneSample -PathLabel $PathLabel -LogFile $LogFile

        if ((Get-Date) -lt $EndTime) {
            Start-Sleep -Seconds $IntervalSeconds
        }
    }
}

Write-Host "SSE Speed Test starting."
Write-Host "Duration per phase : $DurationMinutes minutes"
Write-Host "Baseline           : $BaselineMbps Mbps"
Write-Host "Streams            : $Streams"
Write-Host "Device             : $DeviceLabel"
Write-Host "Download URL       : $DownloadUrl"
Write-Host "Direct log         : $DirectLog"
Write-Host "Prisma Access log  : $PrismaAccessLog"
Write-Host "------------------------------------------------------------------------"

Disconnect-GP
Run-Phase -PathLabel "direct" -LogFile $DirectLog

Connect-GP
Run-Phase -PathLabel "prisma_access" -LogFile $PrismaAccessLog

Write-Host "Test completed."
Write-Host "Direct log        : $DirectLog"
Write-Host "Prisma Access log : $PrismaAccessLog"
