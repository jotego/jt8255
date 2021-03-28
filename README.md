# JT8255
Programmable peripheral interface compatible with Intel 8255, by Jose Tejada (aka jotego)

You can show your appreciation through
* [Patreon](https://patreon.com/topapate), by supporting releases
* [Paypal](https://paypal.me/topapate), with a donation

JT8255 is a PPI written in Verilog, fully compatible with Intel 8255.

## Architecture

Note that the design does not use clock enable signals, and due to the nature of its functionality, it is discouraged to add a clock enable.

The original chip did not have a clock signal, but was completely asynchronous. This modern version uses a clock to detect the input signal edges. It is expected that the devices connecting to this module will share the same clock signal but operate under a clock enable regime that decreases their effective frequency.
