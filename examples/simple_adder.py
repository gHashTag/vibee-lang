#!/usr/bin/env python3
"""
Simple adder example from the Habr article
"""

def adder(a: bool, b: bool, carry_in: bool):
    """
    Full adder implementation
    Returns (sum, carry_out)
    """
    sum_val = a ^ b ^ carry_in
    carry_out = (a & b) | (a & carry_in) | (b & carry_in)
    return sum_val, carry_out