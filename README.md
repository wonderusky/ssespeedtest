# Prisma Access Performance Test

Controlled same-device testing for comparing **MacBook Pro Direct Internet** vs **MacBook Pro Prisma Access / GlobalProtect**.

## Purpose

Measure the performance delta introduced by Prisma Access using repeatable CLI tests instead of relying only on Speedtest.net.

The test captures:

- Single-stream HTTPS throughput
- 16-stream HTTPS aggregate throughput
- Salesforce Time To First Byte
- Zoom latency
- Packet loss
- Public egress IP
- GlobalProtect status

## Files

```text
test.sh                 # Manual test runner
test.sh          # Automated direct + Prisma test
analyze.py               # Optional analysis/graphing script
```

Primary output files:

```text
mbp_direct_16_streams_60min.csv
mbp_prisma_16_streams_60min.csv
```

## Recommended Test

Use the same MacBook Pro for both phases.

Run a short validation first:

```zsh
./test.sh 5 300 16 pangp.gpcloudservice.com mbp
```

Run the full test:

```zsh
./test.sh 60 300 16 pangp.gpcloudservice.com mbp
```

This runs:

```text
60 minutes direct
60 minutes Prisma
plus GlobalProtect reconnect/disconnect time
```

Total runtime is about 2 hours.

## Manual Test Commands

Direct path:

```zsh
rm -f mbp_direct_16_streams.csv
./test.sh 120 300 16 mbp direct mbp_direct_16_streams.csv
```

Prisma path:

```zsh
rm -f mbp_prisma_16_streams.csv
./test.sh 120 300 16 mbp prisma mbp_prisma_16_streams.csv
```

## Default Test Targets

Download test:

```text
https://ash-speed.hetzner.com/100MB.bin
```

SaaS TTFB test:

```text
https://login.salesforce.com
```

Latency test:

```text
zoom.us
```

## Key CSV Fields

| Field | Meaning |
|---|---|
| `Egress_IP` | Public source IP for the test |
| `Single_Mbps` | One HTTPS download stream |
| `Multi_Mbps` | Aggregate throughput across 16 streams |
| `SaaS_TTFB_sec` | Salesforce time to first byte |
| `Latency_Avg_ms` | Average ping latency to Zoom |
| `Packet_Loss_%` | Ping packet loss |
| `GP_Status` | GlobalProtect status at sample time |

## Current 60-Minute Result

Same MacBook Pro, direct vs Prisma:

| Metric | Direct | Prisma |
|---|---:|---:|
| Avg single-stream throughput | ~106 Mbps | ~93 Mbps |
| Median single-stream throughput | ~113 Mbps | ~83 Mbps |
| Avg 16-stream throughput | ~126 Mbps | ~119 Mbps |
| Median 16-stream throughput | ~129 Mbps | ~119 Mbps |
| Avg Salesforce TTFB | ~194 ms | ~266 ms |
| Median Salesforce TTFB | ~198 ms | ~216 ms |
| Avg Zoom latency | ~25 ms | ~26 ms |
| Packet loss | 0% | 0% |

## Interpretation

Same-device testing shows Prisma Access had a modest aggregate throughput reduction versus direct internet access.

The 16-stream average was:

```text
Direct : ~126 Mbps
Prisma : ~119 Mbps
Delta  : ~7 Mbps / ~6%
```

Latency and packet loss were effectively comparable.

Salesforce TTFB was higher through Prisma, but the median delta was smaller than the average because one Prisma sample spiked.

## Customer-Safe Summary

```text
In same-device testing over roughly one hour per path, Prisma Access showed a modest reduction in aggregate 16-stream throughput versus direct internet access, averaging ~119 Mbps compared with ~126 Mbps direct. Packet loss remained 0% and latency was broadly comparable. SaaS TTFB was higher through Prisma, though the median delta was smaller than the average due to one spike.
```

## Notes

Do not use this Cloudflare endpoint for the download test:

```text
https://speed.cloudflare.com/__down?bytes=104857600
```

It returned `HTTP 403` during testing and produced invalid `0 Mbps` results.

Use the Hetzner Ashburn 100 MB file unless there is a reason to change the target.

## Cleanup

Remove old test files before a clean run:

```zsh
rm -f mbp_direct_16_streams_60min.csv
rm -f mbp_prisma_16_streams_60min.csv
```
