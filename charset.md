# minimOS Character Set

*last modified 20180930-1827*

Focused on limited resource platforms, the standard **character set** for minimOS
had to satisfy the following:

- **Single-byte** sequences (for easier/faster parsing).
- Reasonably adhesion to actual standards for convenient **compatibility**.
- Support for **Spanish** characters... plus some other *personal interests* of mine.

Another consideration was trying to match the text-LCD modules charset as much as
possible.

Currently, it is *loosely* based on **ISO 8859-1**. It does however include the
**Euro** sign from 8859-15.

On the other hand, as *C1 control codes* were not defined on that standard, those
were replaced with the following characters from other architectures:

- 128-143 ($80-$8F) are the **Sinclair ZX Spectrum *semi-graphic*** characters.
- 144-159 ($90-$9F) come from $E0-$EF of **code page 437** (*selected Greek for Maths*)
but with four substitutions for equal or similar characters (vgr. using *Beta*
instead of *Eszett*). These alterations are filled with some other characters from
CP437 in the range $F0-$FF which were deemed interesting, like the *check mark*
(actually derived from the *radical sign*), approximation and non-strict
inequalities.
 
Up to 190 ($BE) there are some differences from ISO 8859-1. Beyond that, they are just
the same -- and also like *Windows-1252*, for that matter.

The aforementioned differences include:

- *Non-Breaking space* (160, $A0) is replaced by a hollow square/rectangle. Where
needed, its functionality may be provided by code 128/$80 Spectrum graphic (which
shows up as a blank space anyway).
- *Soft hyphen* (173, $AD) is replaced by the (seldom found on single-byte encodings!)
**slashed equal**.
- *Cedilla* (184, $B8) is not needed as Iberian & Gallic keyboards have the
*C-cedilla* key available, thus is replaced by **lowercase omega**. *This encoding
is already used on some HD44780-based LCD text displays*. 
- *Superscript 1* (185, $B9), unlike the superscript 2 & 3, makes little sense to me,
thus replaced by **uppercase delta**.
- *Fractions* (188-190, $BC-$BE) were to be replaced by *French ligatures and uppercase
Y with diaeresis* but, albeit current, they are rarely used. The latter is replaced
by the **eng** character (required by Wolof language) while the first one will get
the **bullet** character. Note that the *lowercase **oe** ligature* is kept from
ISO 8859-15 as, like the Y with diaeresis, may be an acceptable substitute for the
(rare) appearances of their uppercase counterparts.

## non-ASCII character table

mOS|$x0|$x1|$x2|$x3|$x4|$x5|$x6|$x7|$x8|$x9|$xA|$xB|$xC|$xD|$xE|$xF
---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---
**$8x**| |&#9629;|&#9624;|&#9600;|&#9623;|&#9616;|&#9626;|&#9628;|&#9622;|&#9630;|&#9612;|&#9627;|&#9604;|&#9631;|&#9625;|&#9608;
**$9x**|&#945;|&#10003;|&#915;|&#960;|&#931;|&#963;|&#8804;|&#964;|&#8805;|&#1012;|&#937;|&#948;|&#8734;|&#8776;|&#8712;|&#8745;
**$Ax**|&#9633;|¡|&#162;|£|€|&#165;|&#166;|&#167;|&#168;|&#169;|&#170;|&#171;|&#172;|&#8800;|&#174;|&#175;
**$Bx**|°|&#177;|&#178;|&#179;|&#180;|&#181;|&#182;|&#183;|&#969;|&#916;|&#186;|&#187;|&#8226;|&#339;|&#331;|¿
**$Cx**|À|Á|Â|Ã|Ä|Å|Æ|Ç|È|É|Ê|Ë|Ì|Í|Î|Ï
**$Dx**|Đ|Ñ|Ò|Ó|Ô|Õ|Ö|×|Ø|Ù|Ú|Û|Ü|Ý|&#222;|&#223;
**$Ex**|à|á|â|ã|ä|å|æ|ç|è|é|ê|ë|ì|í|î|ï
**$Fx**|đ|ñ|ò|ó|ô|õ|ö|÷|ø|ù|ú|û|ü|ý|&#254;|&#255;

