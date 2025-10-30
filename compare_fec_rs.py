import argparse
import statistics
import sys
import time
from array import array
from pathlib import Path
from typing import List

import numpy as np
from tabulate import tabulate
from reedsolo import RSCodec

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR / "matrix"))

from matrix_test import run_pipeline  # type: ignore  # noqa: E402


def run_cyclic_pipeline(
    payload_words: List[int],
    packets: List[int],
    m: int,
    k: int,
    symbol_width: int,
) -> tuple[bool, float]:
    """
    Execute the cyclic-shift FEC pipeline and report success plus elapsed time.
    """
    start = time.perf_counter()
    restored, _ = run_pipeline(
        payload=payload_words,
        packets=packets,
        m=m,
        k=k,
        full_width=symbol_width + 1,
    )
    elapsed = time.perf_counter() - start
    return restored == list(payload_words), elapsed


def run_rs_pipeline(
    payload_words: List[int],
    packets: List[int],
    m: int,
    k: int,
    symbol_width: int,
    codec: RSCodec,
) -> tuple[bool, float]:
    """
    Encode/decode with Reed-Solomon (byte-oriented) using the same surviving packets.
    """
    data_array = array("i", payload_words)
    encoded = array("i", codec.encode(data_array))
    keep = set(packets)
    erase_pos = sorted(set(range(k)) - keep)
    received = array("i", encoded)
    for idx in erase_pos:
        received[idx] = 0

    start = time.perf_counter()
    try:
        decoded, _, _ = codec.decode(received, erase_pos=erase_pos)
    except Exception:
        return False, time.perf_counter() - start

    elapsed = time.perf_counter() - start
    return list(decoded) == payload_words, elapsed


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare cyclic-shift FEC with a Reed-Solomon implementation."
    )
    parser.add_argument("--m", type=int, default=3, help="Number of source symbols.")
    parser.add_argument("--k", type=int, default=5, help="Total coded symbols.")
    parser.add_argument(
        "--symbol-width",
        type=int,
        default=10,
        help="Source symbol width in bits (RS codec operates on GF(2^width)).",
    )
    parser.add_argument(
        "--trials",
        type=int,
        default=100,
        help="Number of random trials to execute.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=0,
        help="Master RNG seed for reproducibility.",
    )
    args = parser.parse_args()

    if not (2 <= args.symbol_width <= 16):
        raise ValueError("Symbol width must be between 2 and 16 bits for reedsolo.")

    rng = np.random.default_rng(args.seed)
    rs_codec = RSCodec(
        nsym=args.k - args.m,
        nsize=args.k,
        c_exp=args.symbol_width,
    )

    cyc_successes: List[bool] = []
    rs_successes: List[bool] = []
    cyc_times: List[float] = []
    rs_times: List[float] = []

    for trial in range(args.trials):
        payload_words = rng.integers(
            0,
            2**args.symbol_width,
            size=args.m,
            dtype=np.uint16,
        ).astype(int).tolist()
        packets = sorted(rng.choice(args.k, args.m, replace=False))

        cyc_ok, cyc_elapsed = run_cyclic_pipeline(
            payload_words,
            packets,
            args.m,
            args.k,
            args.symbol_width,
        )
        rs_ok, rs_elapsed = run_rs_pipeline(
            payload_words,
            packets,
            args.m,
            args.k,
            args.symbol_width,
            rs_codec,
        )

        cyc_successes.append(cyc_ok)
        rs_successes.append(rs_ok)
        cyc_times.append(cyc_elapsed)
        rs_times.append(rs_elapsed)

    def summarize(successes: List[bool], timings: List[float]) -> dict:
        return {
            "success": f"{sum(successes)}/{len(successes)}",
            "success_rate": sum(successes) / len(successes),
            "avg_us": statistics.mean(timings) * 1e6,
            "median_us": statistics.median(timings) * 1e6,
        }

    cyc_summary = summarize(cyc_successes, cyc_times)
    rs_summary = summarize(rs_successes, rs_times)

    table = [
        [
            "Cyclic FEC",
            cyc_summary["success"],
            f"{cyc_summary['success_rate']:.2%}",
            f"{cyc_summary['avg_us']:.2f}",
            f"{cyc_summary['median_us']:.2f}",
        ],
        [
            "RS (reedsolo)",
            rs_summary["success"],
            f"{rs_summary['success_rate']:.2%}",
            f"{rs_summary['avg_us']:.2f}",
            f"{rs_summary['median_us']:.2f}",
        ],
    ]

    headers = [
        "scheme",
        "successes",
        "success rate",
        "avg latency (us)",
        "median latency (us)",
    ]
    print(tabulate(table, headers=headers, tablefmt="github"))
    print()
    print(
        f"Parameters: m={args.m}, k={args.k}, symbol_width={args.symbol_width} bits, "
        f"trials={args.trials}, seed={args.seed}"
    )


if __name__ == "__main__":
    main()
