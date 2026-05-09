#!/usr/bin/env python3
"""Summarize SSE Speed Test CSV files."""

from __future__ import annotations

import argparse
import csv
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


METRICS = (
    ("Multi_Mbps", "Multi-stream throughput", "Mbps", True),
    ("Single_Mbps", "Single-stream throughput", "Mbps", True),
    ("SaaS_TTFB_sec", "SaaS TTFB", "ms", False),
    ("Latency_Avg_ms", "Latency", "ms", False),
    ("Packet_Loss_%", "Packet loss", "%", False),
)

DOWNLOAD_ESTIMATES_MB = (100, 500, 1024)


@dataclass(frozen=True)
class Summary:
    count: int
    median: float
    average: float
    minimum: float
    maximum: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare Direct and Prisma Access CSV output from SSE Speed Test."
    )
    parser.add_argument("direct_csv", type=Path, help="CSV file for the Direct Internet run")
    parser.add_argument("prisma_csv", type=Path, help="CSV file for the Prisma Access run")
    return parser.parse_args()


def read_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise SystemExit(f"ERROR: file not found: {path}")

    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def numeric_values(rows: Iterable[dict[str, str]], field: str, scale: float = 1.0) -> list[float]:
    values: list[float] = []

    for row in rows:
        raw_value = row.get(field, "")
        try:
            values.append(float(raw_value) * scale)
        except (TypeError, ValueError):
            continue

    return values


def summarize(values: list[float]) -> Summary | None:
    if not values:
        return None

    return Summary(
        count=len(values),
        median=statistics.median(values),
        average=statistics.fmean(values),
        minimum=min(values),
        maximum=max(values),
    )


def fmt(value: float, unit: str) -> str:
    if unit == "%":
        return f"{value:.1f}%"
    if unit == "ms":
        return f"{value:.1f} ms"
    return f"{value:.2f} {unit}"


def fmt_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{seconds:.1f} sec"

    minutes = int(seconds // 60)
    remaining_seconds = seconds - (minutes * 60)
    return f"{minutes} min {remaining_seconds:.0f} sec"


def delta_text(direct: float, prisma: float, unit: str, _higher_is_better: bool) -> str:
    delta = prisma - direct
    absolute = abs(delta)

    if absolute < 0.000001:
        return "no change"

    direction = "higher" if delta > 0 else "lower"

    if unit == "%":
        absolute_text = f"{absolute:.1f} points"
    else:
        absolute_text = fmt(absolute, unit)

    if direct == 0:
        return f"{absolute_text} {direction}"

    percent_delta = abs((delta / direct) * 100)
    return f"{absolute_text} {direction} ({percent_delta:.1f}%)"


def time_delta_text(direct_seconds: float, prisma_seconds: float) -> str:
    delta = prisma_seconds - direct_seconds
    if abs(delta) < 0.05:
        return "no change"

    direction = "longer" if delta > 0 else "shorter"
    return f"{fmt_duration(abs(delta))} {direction}"


def path_labels(rows: list[dict[str, str]]) -> str:
    labels = sorted({row.get("Path_Label", "").strip() for row in rows if row.get("Path_Label")})
    return ", ".join(labels) if labels else "unknown"


def date_range(rows: list[dict[str, str]]) -> str:
    timestamps = sorted(row.get("Timestamp", "").strip() for row in rows if row.get("Timestamp"))
    if not timestamps:
        return "unknown"
    if timestamps[0] == timestamps[-1]:
        return timestamps[0]
    return f"{timestamps[0]} to {timestamps[-1]}"


def stream_count(rows: list[dict[str, str]]) -> str | None:
    counts = sorted({row.get("Streams_Requested", "").strip() for row in rows if row.get("Streams_Requested")})
    if len(counts) == 1:
        return counts[0]
    return None


def metric_label(field: str, label: str, streams: str | None) -> str:
    if field == "Multi_Mbps" and streams:
        return f"{label} ({streams} streams)"
    if field == "Single_Mbps":
        return f"{label} (1 stream)"
    if field == "Efficiency_%" and streams:
        return f"{label} ({streams} streams)"
    return label


def download_seconds(file_mb: int, mbps: float) -> float:
    return (file_mb * 8) / mbps


def stream_label(streams: str | None) -> str:
    return f"{streams} streams" if streams else "multiple streams"


def main() -> int:
    args = parse_args()
    direct_rows = read_rows(args.direct_csv)
    prisma_rows = read_rows(args.prisma_csv)
    streams = stream_count(direct_rows) if stream_count(direct_rows) == stream_count(prisma_rows) else None

    print("# SSE Speed Test Summary")
    print()
    print(f"- Direct file: `{args.direct_csv}`")
    print(f"- Prisma Access file: `{args.prisma_csv}`")
    print(f"- Direct samples: {len(direct_rows)} ({path_labels(direct_rows)}, {date_range(direct_rows)})")
    print(f"- Prisma Access samples: {len(prisma_rows)} ({path_labels(prisma_rows)}, {date_range(prisma_rows)})")

    direct_single_time = summarize(numeric_values(direct_rows, "Single_Time_sec"))
    prisma_single_time = summarize(numeric_values(prisma_rows, "Single_Time_sec"))
    direct_multi = summarize(numeric_values(direct_rows, "Multi_Mbps"))
    prisma_multi = summarize(numeric_values(prisma_rows, "Multi_Mbps"))

    if direct_single_time and prisma_single_time and direct_multi and prisma_multi:
        print()
        print("## Download Time View")
        print()
        print("| Scenario | Direct (GP Disabled) | Prisma Access (GP Enabled) | Prisma Access Change |")
        print("|---|---:|---:|---|")

        for file_mb in DOWNLOAD_ESTIMATES_MB:
            direct_seconds = download_seconds(file_mb, direct_multi.median)
            prisma_seconds = download_seconds(file_mb, prisma_multi.median)
            file_label = "1 GB" if file_mb == 1024 else f"{file_mb} MB"
            print(
                f"| Estimated {file_label} transfer using {stream_label(streams)} | "
                f"{fmt_duration(direct_seconds)} | {fmt_duration(prisma_seconds)} | "
                f"{time_delta_text(direct_seconds, prisma_seconds)} |"
            )

        print(
            "| Observed 100 MB single-file download | "
            f"{fmt_duration(direct_single_time.median)} | "
            f"{fmt_duration(prisma_single_time.median)} | "
            f"{time_delta_text(direct_single_time.median, prisma_single_time.median)} |"
        )

    print()
    print("## Throughput and Network Details")
    print()
    print("| Metric | Direct (GP Disabled) Median | Prisma Access (GP Enabled) Median | Prisma Access Change |")
    print("|---|---:|---:|---|")

    for field, label, unit, higher_is_better in METRICS:
        scale = 1000.0 if field == "SaaS_TTFB_sec" else 1.0
        direct_summary = summarize(numeric_values(direct_rows, field, scale))
        prisma_summary = summarize(numeric_values(prisma_rows, field, scale))

        if direct_summary is None or prisma_summary is None:
            continue

        delta = delta_text(
            direct_summary.median,
            prisma_summary.median,
            unit,
            higher_is_better,
        )
        print(
            f"| {metric_label(field, label, streams)} | {fmt(direct_summary.median, unit)} | "
            f"{fmt(prisma_summary.median, unit)} | {delta} |"
        )

    print()
    print("## Detail")
    print()
    print("| Metric | Path | Samples | Average | Min | Max |")
    print("|---|---|---:|---:|---:|---:|")

    for field, label, unit, _higher_is_better in METRICS:
        scale = 1000.0 if field == "SaaS_TTFB_sec" else 1.0
        for name, rows in (("Direct (GP Disabled)", direct_rows), ("Prisma Access (GP Enabled)", prisma_rows)):
            summary = summarize(numeric_values(rows, field, scale))
            if summary is None:
                continue

            print(
                f"| {metric_label(field, label, streams)} | {name} | {summary.count} | "
                f"{fmt(summary.average, unit)} | {fmt(summary.minimum, unit)} | "
                f"{fmt(summary.maximum, unit)} |"
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
