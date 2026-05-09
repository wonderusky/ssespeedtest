# SSE Speed Test

SSE Speed Test compares Direct Internet performance against Prisma Access / GlobalProtect performance.

It is built for repeatable CLI-based testing instead of relying only on Speedtest.net or Fast.com.

## Why This Exists

Prisma Access is cloud-delivered. Public speed-test platforms can produce misleading results because traffic may be affected by:

- Speed-test server selection
- Routing and peering differences
- VPN or proxy classification
- Cloud or SSE source IP handling
- Server-side rate limits or throttling
- Single-stream vs multi-stream test behavior
- Test-server load

This tool uses fixed HTTPS download targets and logs the results to CSV.

## Scripts

- test.sh: macOS / Linux
- test.ps1: Windows PowerShell

Both scripts automate the same workflow:

1. Disconnect GlobalProtect
2. Run the Direct Internet test
3. Reconnect GlobalProtect
4. Run the Prisma Access test
5. Save both phases to CSV files

## Metrics Captured

- Public egress IP
- Single-stream HTTPS throughput
- Multi-stream HTTPS aggregate throughput
- Salesforce Time To First Byte
- Zoom latency
- Packet loss
- GlobalProtect status

## Default Test Targets

Download target:

    https://ash-speed.hetzner.com/100MB.bin

SaaS TTFB target:

    https://login.salesforce.com

Latency target:

    zoom.us

Avoid this endpoint unless validated first:

    https://speed.cloudflare.com/__down?bytes=104857600

It returned HTTP 403 during testing and produced invalid 0 Mbps results.

## Run on macOS / Linux

Make the script executable:

    chmod +x test.sh

Run a 5-minute validation test:

    ./test.sh 5 300 16 pangp.gpcloudservice.com test-device

Run a full 60-minute test:

    ./test.sh 60 300 16 pangp.gpcloudservice.com test-device

Arguments:

    $1 = test duration in minutes per phase
    $2 = baseline Mbps
    $3 = number of parallel streams
    $4 = GlobalProtect portal
    $5 = device label
    $6 = optional download URL
    $7 = optional curl timeout seconds

Example with explicit download URL:

    ./test.sh 60 300 16 pangp.gpcloudservice.com test-device "https://ash-speed.hetzner.com/100MB.bin" 300

## Run on Windows PowerShell

Open PowerShell and go to the repo folder:

    cd $HOME\Code\SSEspeedtest

Allow script execution for the current session:

    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

Run a 5-minute validation test:

    .\test.ps1 -DurationMinutes 5 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test

Run a full 60-minute test:

    .\test.ps1 -DurationMinutes 60 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test

PowerShell parameters:

    -DurationMinutes = test duration in minutes per phase
    -BaselineMbps    = baseline Mbps
    -Streams         = number of parallel streams
    -Portal          = GlobalProtect portal
    -DeviceLabel     = device label
    -DownloadUrl     = optional download URL
    -CurlMaxTime     = optional curl timeout seconds

Example with explicit download URL:

    .\test.ps1 -DurationMinutes 60 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test -DownloadUrl "https://ash-speed.hetzner.com/100MB.bin" -CurlMaxTime 300

## Runtime

A 60-minute run means:

    60 minutes Direct Internet
    60 minutes Prisma Access
    plus GlobalProtect disconnect/reconnect time

Approximate total runtime is about 2 hours.

A 5-minute validation run takes about 10 to 15 minutes.

## Output Files

The scripts create one CSV file per test phase.

Example macOS / Linux output:

    test-device_direct_16_streams_60min.csv
    test-device_prisma_16_streams_60min.csv

Example Windows output:

    windows-test_direct_16_streams_60min.csv
    windows-test_prisma_access_16_streams_60min.csv

The CSV files included in this repository are sample outputs from prior test runs.

## Key CSV Fields

- Timestamp: time of sample
- Device_Label: device label provided at runtime
- Path_Label: Direct or Prisma Access path
- Egress_IP: public source IP
- Download_URL: HTTPS file used for download testing
- Streams_Requested: number of parallel streams
- Single_Mbps: single HTTPS stream throughput
- Multi_Mbps: aggregate multi-stream throughput
- SaaS_TTFB_sec: Salesforce time to first byte
- Latency_Avg_ms: average latency to Zoom
- Packet_Loss_%: packet loss percentage
- GP_Status: GlobalProtect status at sample time

## Interpreting Results

Single_Mbps measures one HTTPS download stream.

Multi_Mbps measures aggregate throughput across multiple HTTPS streams.

SaaS_TTFB_sec measures Time To First Byte to Salesforce. For example:

    0.250000 = 250 ms

This is not a full page-load test. It measures how long it takes to receive the first byte from the SaaS endpoint.

Packet_Loss_% is measured using ICMP ping to zoom.us.

Median is preferred for headline comparisons because it reflects typical performance and reduces the impact of isolated spikes. Average is still useful as supporting context, but it can be skewed by one-off outliers.

## Latest Same-Device Result

Test environment:

- Device: MacBook Pro M5
- Internet service: 300 Mbps Astound cable connection
- Wi-Fi: Google Nest Wifi router
- Note: The Google Nest Wifi / local Wi-Fi path was likely the bottleneck during testing, so these results should be interpreted as path comparison data, not Prisma Access maximum throughput capacity.

Same device, Direct Internet vs Prisma Access, 16 streams:

| Metric | Direct Median | Prisma Access Median | Takeaway |
|---|---:|---:|---|
| Single-stream throughput | ~113 Mbps | ~83 Mbps | Prisma Access lower |
| 16-stream throughput | ~129 Mbps | ~119 Mbps | Prisma Access modestly lower |
| Salesforce TTFB | ~198 ms | ~216 ms | Prisma Access slightly higher |
| Zoom latency | ~24 ms | ~24 ms | Comparable |
| Packet loss | 0% | 0% | No loss observed |

## Summary

In same-device testing, Prisma Access showed a modest aggregate throughput reduction versus Direct Internet. Packet loss remained 0% and latency was broadly comparable. Salesforce TTFB was slightly higher through Prisma Access based on median results.

Use the same device and same network when comparing Direct Internet and Prisma Access. This avoids skew from different Wi-Fi radios, hardware, OS behavior, background applications, or local network conditions.

For formal testing, run the 5-minute validation first. Then run the full 60-minute test.
