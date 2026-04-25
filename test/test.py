# SPDX-FileCopyrightText: TOCAD Irrigation Chip
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

@cocotb.test()
async def test_project(dut):
    dut._log.info("TOCAD Irrigation Chip -- Simulation Start")

    # Clock: 10kHz = 100us period
    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value   = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # ------------------------------------------------
    # TEST 1: DFT manual trigger
    # Zone 0 dry, press test button, valve 0 should open
    # freq=000, dur=000 (DFT overrides to 5s)
    # ------------------------------------------------
    dut._log.info("TEST 1: DFT manual trigger")
    dut.ui_in.value  = 0b00000001   # zone 0 DRY
    dut.uio_in.value = 0b00000001   # TEST_MANUAL HIGH
    await ClockCycles(dut.clk, 20)
    dut.uio_in.value = 0b00000000   # release button
    await ClockCycles(dut.clk, 200)

    valve_state = int(dut.uo_out.value) & 0x7F
    assert valve_state > 0, f"TEST 1 FAIL: No valve opened, uo_out={dut.uo_out.value}"
    dut._log.info(f"TEST 1 PASS: valve state = {bin(valve_state)}")

    # ------------------------------------------------
    # TEST 2: Rain lockout
    # Reset first to clear all state cleanly
    # Then set rain HIGH before any DFT press
    # ------------------------------------------------
    dut._log.info("TEST 2: Rain lockout")

    # Clean reset
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # Now set rain HIGH then press DFT
    dut.ui_in.value  = 0b10000001   # zone 0 DRY + rain ON
    dut.uio_in.value = 0b00000001   # TEST_MANUAL
    await ClockCycles(dut.clk, 20)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 500)

    valve_state = int(dut.uo_out.value) & 0x7F
    assert valve_state == 0, \
        f"TEST 2 FAIL: Valve opened despite rain, uo_out={dut.uo_out.value}"
    dut._log.info("TEST 2 PASS: Rain correctly blocked watering")

    # ------------------------------------------------
    # TEST 3: Reset clears state
    # ------------------------------------------------
    dut._log.info("TEST 3: Reset")
    dut.ui_in.value  = 0b01111111   # all zones DRY
    dut.uio_in.value = 0b00000001   # DFT
    await ClockCycles(dut.clk, 20)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 500)

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 100)

    valve_state = int(dut.uo_out.value) & 0x7F
    assert valve_state == 0, f"TEST 3 FAIL: Valves not cleared on reset, uo_out={dut.uo_out.value}"
    dut._log.info("TEST 3 PASS: Reset cleared all valves")

    dut._log.info("ALL TESTS PASSED")
