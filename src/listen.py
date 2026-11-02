
#!/usr/bin/env python3

import argparse


def parse_args():
    parser = argparse.ArgumentParser(
        description="Configure frequencies for a WWV time-signal receiver."
    )

    parser.add_argument(
        "-f",
        "--frequency",
        type=float,
        nargs="+",
        required=True,
        metavar="MHz",
        help=(
            "One or more frequencies in MHz. "
            "Example: -f 5 10 15"
        ),
    )

    return parser.parse_args()


def main():
    args = parse_args()

    frequencies = args.frequency

    for frequency in frequencies:
        if not 0.5 <= frequency <= 30:
            raise SystemExit(
                f"Error: {frequency} MHz is outside the allowed "
                "range of 0.5–30 MHz."
            )

    print("WWV Time Signal Receiver")
    print("========================")
    print("Selected frequencies:")

    for frequency in frequencies:
        print(f"  {frequency:g} MHz")

    print()
    print("Configuration validated.")
    print("SDR hardware is not accessed in this version.")


if __name__ == "__main__":
    main()
