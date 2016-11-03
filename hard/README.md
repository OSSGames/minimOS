#Hardware for minimOS



##Supported architectures

With great embarrassment I have to admit never have owned a 65xx computer... but suport for these classic machines shouldn't be difficult to add -- for instance, I have declared as 'reserved' the two first zero-page bytes in case the utterly popular Commodore-64 (using a 6510) is targeted. Back to my own-designed machines, here's the current history & roadmap:

**MTE _("Medidor de Tiempos de Exposición", Exposure Time Meter)_**

Status: finishing design.

Form-factor: soldered PCB.

Specs: 1 MHz 6503 (28 pin, 4 kiB addressing space), 128-byte RAM, 3 kiB-EPROM (addressable range from a 2732), VIA 6522

Intefaces: four (very large) 7-segment LED digits, light sensor, a couple of keys...



**SDd _("Sistema de Desarrollo didáctico", Learning Development System)_**

Status: WORKING!

Form-factor: solderless breadboard.

Specs: 1 MHz 65SC02, 2 kiB RAM, 2-4 kIB (E)EPROM, VIA 65C22.

Interfaces: Amplified piezo buzzer between PB7-CB2, currently with a VIA-attached 4-digit LED-keypad.



**CHIHUAHUA**

Status: finished and _sort-of_ working, but with some strange malfunction :-(

Form-factor: Breadboard with point-to-point soldering.

Specs: Soldered, compact version of SDd. Strange bug with VIA, not solved yet. Probably will be discarded.

Interfaces: Piezo buzzer between PB7-CB2, SS-22 and VIA-port connectors.


**CHIHUAHA PLUS**

Status: under construction.

Form-factor: Breadboard with point-to-point soldering.

Specs: 1 MHz (socketed osc.) 65C02, 16 kiB RAM, 32 kiB EPROM, VIA 65C22.

Interfaces: Amplified piezo buzzer between PB7-CB2, SS-22 and VIA-port connectors.




**SDx _("Sistema de Desarrollo eXpandible", Expansible Develpment System)_**

Status: aborted :-(

Form-factor: Breadboard with point-to-point soldering.

Specs: 1.25 / 2 MHz 65C02/102, 8-16 kIB RAM, 32 kiB EPROM, VIA 65C22, ACIA 65SC51, RTC 146818.

Interfaces: Amplified piezo buzzer between PB7-CB2, Hitachi LCD, TTL-level RS-232, SS-22 and VIA-port connectors. Several diagnostic LEDs.


**Baja**

Status: never started :-(

Specs: intended to be a fully bankswitching 65C02 SBC, but also pluggable into a backplane.



**Jalapa (formerly SDm)**

Status: finishing design.

Form-factor: Breadboard with point-to-point soldering.

Specs: 1.8432 / 2.304 MHz 65C02, 128 kiB RAM (16K + 7x16K banks), 32 kiB EPROM, VIA 65C22, ACIA 65SC51.

Intefaces: Amplified piezo buzzer between PB7-CB2, SS-22, VIA (SBC-2 style but with "mirrored" power pins), TTL-level RS-232, *miniBus* slot (6502 direct expansion)


**Tijuana**

Status: finishing design.

Form-factor: Single layer PCB?

Specs: 3.072 MHz 65C02, 2-8 kiB SRAM, 3x32 kiB VRAM, 16 kiB EPROM, VIA 65C22, CRTC HD46505, ACIA 6551A. *Intended to be a colour & graphics capable VT-52 based terminal.*

Interfaces: Piezo buzzer, TTL-level async., SS-22, parallel input, VGA-compatible video output (576x448 @ 1 bpp, 3-bit RGB or 3-bit greyscale), *miniBus* slot (6502 direct expansion) 



**Veracruz**

Status: in design stage

Form-factor: ?

Specs: 2 MHz (at least) 65816, 512 kiB RAM, 32 kiB EPROM, 2 x VIA 65C22, UART 16C550, RTC MC146818.

Interfaces: Piezo buzzer, new VIA and SS-22 connectors, TTL-level async, 65SIB, Hitachi LCD thru VIA, maybe I2C, *miniBus* slot (6502 direct expansion)



**Jalisco**

Status: in design stage

Form-factor: 4-layer PCB, SMD components.

Specs: 12 MHz (I hope!) 65816, up to 8 MiB RAM (2 x Garth's modules), 32 kiB Kernel + 2 MiB EPROM (?), 2 x VIA 65C22, (2x) UART.

Interfaces: most likely those of Veracruz, possibly plus SD-card, text console output...

*...more to come!*