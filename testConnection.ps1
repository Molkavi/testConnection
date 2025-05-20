# Settings
$TargetHost = "8.8.8.8" # Google DNS
$PingIntervalSeconds = 5 # in seconds
$LatencySpikeThreshold = 100 # in milliseconds

# Get Desktop path
$DesktopPath = [Environment]::GetFolderPath("Desktop")

# Function to get today's log file path
function Get-LogFilePath {
    $date = Get-Date -Format "yyyy-MM-dd"
    return Join-Path $DesktopPath "InternetMonitorLog-$date.csv"
}

# Ensure today's log file has headers
function Ensure-LogHeader {
    param ($path)
    if (!(Test-Path $path)) {
        "Timestamp,Status,LatencyMs,Message" | Out-File -FilePath $path -Encoding utf8
    }
}

function Show-Spinner {
    param([int]$DurationSeconds)

    $frames = @("|", "/", "-", "\")
    $end = [datetime]::Now.AddSeconds($DurationSeconds)
    $i = 0

    while ([datetime]::Now -lt $end) {
        $frame = $frames[$i % $frames.Length]
        Write-Host -NoNewline "`r$frame Monitoring..." -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 250
        $i++
    }

    Write-Host -NoNewline "`r " # Clear spinner line
}

Write-Host "Monitoring $TargetHost every $PingIntervalSeconds second(s)..."
Write-Host "Logs saved daily to: $DesktopPath"
Write-Host "Press Ctrl+C to stop the script." -ForegroundColor Cyan
Write-Host "Only lag spikes or connection errors will be shown below. OK pings are logged silently." -ForegroundColor Gray

while ($true) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = Get-LogFilePath
    Ensure-LogHeader -path $logFile

    $pingResult = Test-Connection -ComputerName $TargetHost -Count 1 -ErrorAction SilentlyContinue

    if ($pingResult) {
        $latency = [math]::Round($pingResult.ResponseTime, 2)
        if ($latency -gt $LatencySpikeThreshold) {
            "$timestamp,Lag Spike,$latency,Latency exceeded ${LatencySpikeThreshold}ms" | Out-File -FilePath $logFile -Append -Encoding utf8
            Write-Host "[$timestamp] Lag spike: $latency ms" -ForegroundColor Yellow
        } else {
            "$timestamp,OK,$latency," | Out-File -FilePath $logFile -Append -Encoding utf8
        }
    } else {
        "$timestamp,Timeout,0,No response from $TargetHost" | Out-File -FilePath $logFile -Append -Encoding utf8
        Write-Host "[$timestamp] Timeout: No response" -ForegroundColor Red
    }
    
    Show-Spinner -DurationSeconds $PingIntervalSeconds
}