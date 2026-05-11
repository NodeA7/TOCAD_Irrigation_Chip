import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

def read_valves(dut):
    """Safely read valve bits, treating X as 0"""
    try:
        return int(dut.uo_out.value) & 0x7F
    except ValueError:
        # Contains X/Z values — not settled yet, treat as 0
        raw = str(dut.uo_out.value)
        result = 0
        for i, bit in enumerate(reversed(raw)):
            if bit == '1':
                result |= (1 << i)
        return result & 0x7F

@cocotb.test()
async def test_project(dut):
    dut._log.info("TOCAD Irrigation Chip -- Simulation Start")

    clock = Clock(dut.clk, 100, unit="us")
    cocotb.start_soon(clock.start())

   try:
    dut.VPWR.value = 1
    dut.VGND.value = 0
    await ClockCycles(dut.clk, 10)
except AttributeError:
    pass  # RTL simulation, no power pins needed

    # Reset
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 20)

    # ------------------------------------------------
    # TEST 1: DFT manual trigger
    # ------------------------------------------------
    dut._log.info("[TEST 1] DFT Trigger Zone 0")
    dut.ui_in.value  = 0b00000001
    dut.uio_in.value = 0b00000001   # test_btn HIGH
    await ClockCycles(dut.clk, 50)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 500)

    valve_state = read_valves(dut)
    assert valve_state > 0, \
        f"TEST 1 FAIL: No valve opened, uo_out={dut.uo_out.value}"
    dut._log.info(f"TEST 1 PASS: valve state = {bin(valve_state)}")

    # ------------------------------------------------
    # TEST 2: Rain lockout
    # ------------------------------------------------
    dut._log.info("[TEST 2] Rain lockout")
    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 20)

    dut.ui_in.value  = 0b10000001   # zone 0 DRY + rain
    dut.uio_in.value = 0b00000001
    await ClockCycles(dut.clk, 50)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 500)

    valve_state = read_valves(dut)
    assert valve_state == 0, \
        f"TEST 2 FAIL: Valve opened despite rain, uo_out={dut.uo_out.value}"
    dut._log.info("TEST 2 PASS: Rain correctly blocked watering")

    # ------------------------------------------------
    # TEST 3: Reset clears state
    # ------------------------------------------------
    dut._log.info("[TEST 3] Reset clears state")
    dut.ui_in.value  = 0b01111111
    dut.uio_in.value = 0b00000001
    await ClockCycles(dut.clk, 50)
    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 500)

    dut.rst_n.value  = 0
    await ClockCycles(dut.clk, 50)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 100)

    valve_state = read_valves(dut)
    assert valve_state == 0, \
        f"TEST 3 FAIL: Valves not cleared on reset, uo_out={dut.uo_out.value}"
    dut._log.info("TEST 3 PASS: Reset cleared all valves")

    dut._log.info("ALL TESTS PASSED")
