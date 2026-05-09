# SSE Speed Test

CLI-based test for measuring the performance difference between Direct Internet and Prisma Access / GlobalProtect.

Main script: test.sh

## Purpose

Measure the performance delta introduced by Prisma Access using repeatable CLI tests instead of relying only on Speedtest.net or Fast.com.

Prisma Access is cloud-delivered, so public speed-test platforms can give misleading results due to server selection, routing, peering, VPN/proxy classification, cloud/SSE source IP treatment, server-side throttling or rate limits, and test-server load.

## What test.sh Does

The script automates the full workflow:

1. Disconnects GlobalProtect
2. Runs the Direct Internet test
3. Reconnects GlobalProtect
4. Runs the Prisma Access test
5. Logs both phases to CSV

## Metrics Captured

- Public egress IP
- Single-stream HTTPS throughput
- Multi-stream HTTPS aggregate throughput
- Salesforce Time To First Byte
- Zoom latency
- Packet loss
- GlobalProtect status

## Sample CSV Files

The CSV files in this repo are sample outputs from prior test runs:

- mbp_direct_16_streams_60min.csv
- mbp_prisma_16_streams_60min.csv

## Run Example

chmod +x test.sh
./test.sh 60 300 16 pangp.gpcloudservice.com test-device

## Arguments

$1 = test duration in minutes per phase
$2 = baseline Mbps
$3 = number of parallel streams
$4 = GlobalProtect portal
$5 = device label

## Runtime

A 60-minute run takes approximately:

60 minutes Direct Internet
60 minutes Prisma Access
plus GlobalProtect disconnect/reconnect time

## Default Test Targets

Download target:
https://ash-speed.hetzner.com/100MB.bin

SaaS TTFB target:
https://login.salesforce.com

Latency target:
zoom.us

## Latest Same-Device Result

Same device, direct vs Prisma Access, 16 streams:

| Metric | Direct | Prisma |
|---|---:|---:|
| Avg single-stream throughput | ~106 Mbps | ~93 Mbps |
| Avg 16-stream throughput | ~126 Mbps | ~119 Mbps |
| Avg Salesforce TTFB | ~194 ms | ~266 ms |
| Avg Zoom latency | ~25 ms | ~26 ms |
| Packet loss | 0% | 0% |

## Summary

In same-device testing, Prisma Access showed a modest aggregate throughput reduction versus direct internet access. Packet loss remained 0% and latency was broadly comparable. Salesforce TTFB was higher through Prisma Access.

