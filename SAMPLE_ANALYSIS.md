# SSE Speed Test Summary

- Direct file: `mbp_direct_16_streams_60min.csv`
- Prisma Access file: `mbp_prisma_16_streams_60min.csv`
- Direct samples: 15 (direct, 2026-05-08 21:29:34 to 2026-05-08 22:28:03)
- Prisma Access samples: 14 (prisma, 2026-05-08 22:32:11 to 2026-05-08 23:28:13)

## Download Time View

| Scenario | Direct (GP Disabled) | Prisma Access (GP Enabled) | Prisma Access Change |
|---|---:|---:|---|
| Estimated 100 MB transfer using 16 streams | 6.2 sec | 6.7 sec | 0.5 sec longer |
| Estimated 500 MB transfer using 16 streams | 31.1 sec | 33.6 sec | 2.5 sec longer |
| Estimated 1 GB transfer using 16 streams | 1 min 4 sec | 1 min 9 sec | 5.1 sec longer |
| Observed 100 MB single-file download | 7.4 sec | 10.1 sec | 2.7 sec longer |

## Throughput and Network Details

| Metric | Direct (GP Disabled) Median | Prisma Access (GP Enabled) Median | Prisma Access Change |
|---|---:|---:|---|
| Multi-stream throughput (16 streams) | 128.54 Mbps | 118.96 Mbps | 9.58 Mbps lower (7.5%) |
| Single-stream throughput (1 stream) | 113.22 Mbps | 83.38 Mbps | 29.84 Mbps lower (26.4%) |
| SaaS TTFB | 197.6 ms | 216.5 ms | 18.8 ms higher (9.5%) |
| Latency | 23.8 ms | 23.7 ms | 0.1 ms lower (0.3%) |
| Packet loss | 0.0% | 0.0% | no change |

## Detail

| Metric | Path | Samples | Average | Min | Max |
|---|---|---:|---:|---:|---:|
| Multi-stream throughput (16 streams) | Direct (GP Disabled) | 15 | 126.21 Mbps | 111.37 Mbps | 138.78 Mbps |
| Multi-stream throughput (16 streams) | Prisma Access (GP Enabled) | 14 | 118.97 Mbps | 101.22 Mbps | 135.95 Mbps |
| Single-stream throughput (1 stream) | Direct (GP Disabled) | 15 | 105.97 Mbps | 59.90 Mbps | 125.22 Mbps |
| Single-stream throughput (1 stream) | Prisma Access (GP Enabled) | 14 | 92.64 Mbps | 69.45 Mbps | 136.42 Mbps |
| SaaS TTFB | Direct (GP Disabled) | 15 | 194.1 ms | 151.2 ms | 222.4 ms |
| SaaS TTFB | Prisma Access (GP Enabled) | 14 | 265.6 ms | 153.5 ms | 735.3 ms |
| Latency | Direct (GP Disabled) | 15 | 25.1 ms | 19.2 ms | 33.5 ms |
| Latency | Prisma Access (GP Enabled) | 14 | 26.4 ms | 20.4 ms | 49.1 ms |
| Packet loss | Direct (GP Disabled) | 15 | 0.0% | 0.0% | 0.0% |
| Packet loss | Prisma Access (GP Enabled) | 14 | 0.0% | 0.0% | 0.0% |
