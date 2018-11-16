![alt text](https://github.com/klaviana/exocoder/blob/master/exocoder.jpg "The Exocoder")

# The Exocoder

The Exocoder is a multidimensional polyphonic vocoder -- multidimensional in that it allows various (both physical and virtual) degrees of expression, and polyphonic in that it allows for more than one pitch so that harmonically complex songs are playable. Above all, the Exocoder looks to add a physical element to electronic music performance. 

The bulk of the Exocoder's source code is in the strongly-timed audio language ChucK, which allowed me to alter pitches using a Fast Fourier Transform and create compelling soundscapes with various effects and ugens.

Data was read from the device using Arduino and sent to ChucK as MIDI signals containing frequency and amplitude values. A Gametrak string attached to each arm allows the user to control parameters via the distance between each hand -- volume (x), filter sweeping (y), vibrato (z).

The Exocoder uses an Espressif ESP32 board, which allowed the instrument to be wireless due the board's WiFi capabilities. I wasn't able to find much documentation online about integrating ESP32's WiFi and MIDI protocol, but ended up getting it to work using Apple Midi.

Browse my other projects or learn about me at [laviana.me](https://laviana.me).