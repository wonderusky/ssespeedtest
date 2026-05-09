# SSE Speed Test for Windows

SSE Speed Test compares Direct Internet performance with Prisma Access / GlobalProtect performance using repeatable HTTPS download, SaaS TTFB, latency, and packet-loss samples.

The Windows script runs both phases automatically: GlobalProtect disconnect, Direct Internet phase, GlobalProtect reconnect, Prisma Access phase, and CSV output.

## What It Measures

- Public egress IP
- Single-file HTTPS download time and throughput
- Multi-stream HTTPS aggregate throughput
- Salesforce time to first byte
- Zoom latency
- Packet loss
- GlobalProtect status

Default targets:

```text
Download: https://ash-speed.hetzner.com/100MB.bin
SaaS TTFB: https://login.salesforce.com
Latency: zoom.us
```

## Download

Clone the repository:

```powershell
git clone https://github.com/wonderusky/ssespeedtest.git SSEspeedtest
cd SSEspeedtest
```

Or download the repository as a ZIP file, extract it, and open PowerShell in the extracted `SSEspeedtest` folder.

If you already have the repository locally:

```powershell
cd $HOME\Code\SSEspeedtest
git pull
```

## Requirements

- PowerShell 5 or newer
- `curl.exe`
- GlobalProtect client, if you want automated disconnect/reconnect
- Python 3.10 or newer for result analysis

## Recommended Workflow

Use the same device, network, location, stream count, and download target for both phases.

1. Allow script execution for the current PowerShell session.
2. Run a short validation test.
3. Confirm both CSV files contain non-zero `Single_Mbps` and `Multi_Mbps` values.
4. Run the full test.
5. Analyze both CSVs together.

A 60-minute comparison takes about 2 hours plus GlobalProtect disconnect and reconnect time.

## Run on Windows

Allow script execution for the current session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Run a short validation test:

```powershell
.\test.ps1 -DurationMinutes 5 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test
```

Run the full test:

```powershell
.\test.ps1 -DurationMinutes 60 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test
```

Optional explicit download URL:

```powershell
.\test.ps1 -DurationMinutes 60 -BaselineMbps 300 -Streams 16 -Portal pangp.gpcloudservice.com -DeviceLabel windows-test -DownloadUrl "https://ash-speed.hetzner.com/100MB.bin" -CurlMaxTime 300
```

Output files:

```text
<device>_direct_<streams>_streams_<duration>min.csv
<device>_prisma_access_<streams>_streams_<duration>min.csv
```

Example:

```text
windows-test_direct_16_streams_60min.csv
windows-test_prisma_access_16_streams_60min.csv
```

## Analyze Results

Compare the two output CSV files:

```powershell
python .\analyze_results.py .\windows-test_direct_16_streams_60min.csv .\windows-test_prisma_access_16_streams_60min.csv
```

The analyzer prints:

- Sample counts and time ranges
- Download-time comparison
- Median throughput, TTFB, latency, and packet-loss comparison
- Detail table with average, minimum, and maximum values

## CSV Fields

Common fields:

- `Timestamp`: sample time
- `Device_Label`: device label provided at runtime
- `Path_Label`: `direct` or `prisma_access`
- `Egress_IP`: public source IP
- `Download_URL`: HTTPS file used for download testing
- `Streams_Requested`: number of parallel streams
- `Single_HTTP`: HTTP status from the single-stream download
- `Single_Bytes`: bytes downloaded by the single-stream test
- `Single_Time_sec`: single-stream download duration
- `Single_Mbps`: single-stream throughput
- `Multi_Streams_Successful`: successful parallel download count
- `Multi_Bytes`: aggregate bytes downloaded by all successful streams
- `Multi_Time_sec`: multi-stream wall-clock duration
- `Multi_Mbps`: aggregate multi-stream throughput
- `Efficiency_%`: `Multi_Mbps` as a percentage of the configured baseline Mbps
- `SaaS_URL`: SaaS endpoint used for TTFB
- `SaaS_TTFB_sec`: time to first byte, in seconds
- `Ping_Target`: latency target
- `Latency_Avg_ms`: average latency
- `Packet_Loss_%`: packet loss percentage
- `GP_Status`: GlobalProtect status at sample time

## Interpreting Results

`Multi_Mbps` is the primary throughput comparison. It estimates aggregate transfer performance using parallel HTTPS downloads.

`Single_Mbps` and `Single_Time_sec` describe one HTTPS download flow. They are useful diagnostics for single-file or one-flow behavior.

`SaaS_TTFB_sec` is not a full page-load metric. For example, `0.250000` means 250 ms to receive the first byte from Salesforce.

`Packet_Loss_%` uses ICMP ping to `zoom.us`. Some networks treat ICMP differently from application traffic, so use it as a signal rather than a complete voice/video quality test.

`GP_Status` is written to the Windows CSV so you can confirm the observed GlobalProtect state at sample time. If GlobalProtect reconnect requires interactive login, complete the login prompt before relying on the Prisma Access phase.

## Sample Data

This repository includes sample CSVs from a prior same-device run and the generated analyzer output.

```text
mbp_direct_16_streams_60min.csv
mbp_prisma_16_streams_60min.csv
SAMPLE_ANALYSIS.md
```

Regenerate the sample analysis with:

```powershell
python .\analyze_results.py .\mbp_direct_16_streams_60min.csv .\mbp_prisma_16_streams_60min.csv > SAMPLE_ANALYSIS.md
```
