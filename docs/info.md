<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

# TOCAD Irrigation Chip

## How it works

This chip is designed to be the "brain" of a multi-zone garden watering system. It makes sure your plants get water when they need it, without ruining your water pressure or flooding your yard.

The chip has a built-in "manager" (technically it's called an arbiter). It constantly checks up to 7 soil moisture sensors. If a lot of zones are dry at the same time, the manager makes a queue. It will only allow a maximum of 4 valves to open at once to keep the water pressure strong. As soon as one zone finishes watering, the next one in line automatically starts.

It also has a safety feature: a "3-strike" rule. If it waters a zone but the sensor still reads as completely dry three times in a row, the chip assumes something is broken (like a snapped pipe or a bad sensor). It will lock that zone out and blink a warning light so you know to go check on it. It also has a master "rain lockout" to stop all watering if it's currently raining.

## How to test

If you are testing this chip on the Tiny Tapeout Demo Board, you don't need real water or dirt! 

1. **Set the timers:** Use the input switches (`uio` switches 1 to 6) to set how often it checks the soil (pins 1, 2, 3) and how long it water (pins 4,5,6).
2. **Simulate a dry garden:** Flip the main input switches (`ui` switches 0 through 6) to the "ON" position. This tells the chip the soil is dry.
3. **Watch the traffic jam:** Notice that even if you flip all 7 "dry" switches on, only 4 output LEDs will light up. Wait a few seconds for the watering time to finish, and you'll see the LEDs swap as the chip automatically handles the rest of the queue.
4. **Make it rain:** Flip `ui` switch 7 to "ON". All the "valve" LEDs will turn off immediately.
5. **Check the heartbeat:** The 8th output LED is your system health light. A steady, slow blink means everything is fine. A fast, frantic blink means the 3-strike safety feature caught a broken zone.

## Watering Configuration Table

To set your times, look at the 3-bit binary code (e.g., 010).  
The first bit is the "A" pin (the highest pin number), the middle is "B", and the last is "C" (the lowest pin number).

### Frequency (How Often)
(A = uio[3], B = uio[2], C = uio[1])
| Binary | Resulting Time |
|--------|----------------|
| `000` | 30 Minutes |
| `001` | 1 Hour |
| `010` | 2 Hours |
| `011` | 3 Hours |
| `100` | 4 Hours |
| `101` | 6 Hours |
| `110` | 8 Hours |
| `111` | 12 Hours |

### Duration (How Long)
(A = uio[6], B = uio[5], C = uio[4])
| Binary | Resulting Time |
|--------|----------------|
| `000` | 10 Seconds |
| `001` | 20 Seconds |
| `010` | 30 Seconds |
| `011` | 40 Seconds |
| `100` | 50 Seconds |
| `101` | 60 Seconds |
| uio[6] | uio[5] | uio[4] | `110` | 90 Seconds |
| uio[6] | uio[5] | uio[4] | `111` | 120 Seconds |

> **Note:** "0" means the switch is OFF (Down), and "1" means the switch is ON (Up).

## External hardware

You can test the entire chip using just the built-in DIP switches (as inputs) and LEDs (as outputs) on the standard **Tiny Tapeout Demo Board**. 

However, if you want to take this off the test bench and actually plug it into your garden, here is what you would attach to the board's pins:

* **For the Inputs (The Senses):** Standard 3.3V soil moisture sensors (the common ones you can easily plug into a breadboard) and a basic rain sensor module.
* **For the Outputs (The Muscle):** The chip only outputs a tiny 3.3V signal, so you can't plug a heavy-duty water valve directly into it. You will need a standard **Relay Board** or a **MOSFET driver PMOD**. This acts as a bridge, allowing the chip's tiny signals to safely turn on the bigger 12V or 24V power supplies needed for real solenoid water valves.
