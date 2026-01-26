#!/usr/bin/env python3
"""
Simple adder function example for py2vibee testing
"""

def adder(a: int, b: int, carry_in: bool) -> tuple:
    """
    Full adder implementation
    Returns (sum, carry_out)
    """
    sum_val = a ^ b ^ carry_in
    carry_out = (a & b) | (a & carry_in) | (b & carry_in)
    return sum_val, carry_out


def counter(clk: bool, reset: bool, enable: bool) -> int:
    """
    Simple counter with reset and enable
    """
    # This would be stateful in hardware
    # For spec generation, we just document behavior
    if reset:
        return 0
    elif enable and clk:
        # Increment on rising clock edge when enabled
        return "current_count + 1"
    else:
        return "current_count"


def led_blinker(clk: bool, reset: bool, speed: int) -> bool:
    """
    LED blinker with configurable speed
    """
    if reset:
        return False
    # Toggle LED based on counter and speed setting
    return "(counter % (CLOCK_FREQ // speed)) == 0"