/*
name: vocoder.ck
desc: Ambient Midi Vocoder
by: Kyle Laviana

Code Resources:
--Ananya Misra and Ge Wang: polyfony.ck
--Eduard Aylon: vocoder.ck
--Gio Jacuzzi: voxbox.ck
*/

0 => int onOrOff;

// Input
    // synth
    Gain line_synth => FFT fft_synth => blackhole;
    // mic
    adc.left => PoleZero dcblock_mic => FFT fft_mic => blackhole;

// Output
    // processed audio
    IFFT ifft_output => PoleZero dcblock_output => PitShift shift => Chorus chorus => LPF filter_lpf => HPF filter_hpf => JCRev reverb => Gain vocoderOutput => dac;
    // unprocessed audio
    adc => Gain adcOutput => dac;

// Midi Set-up
//---------------------------------------------------------------------
    // device to open (see: chuck --probe)
    0 => int device;
    // get from command line
    if( me.args() ) me.arg(0) => Std.atoi => device;

    MidiIn min;
    MidiMsg msg;

    // try to open MIDI port (see chuck --probe for available devices)
    if(!min.open(device)) me.exit();

    // print out device that was opened
    <<< "MIDI device:", min.num(), " -> ", min.name() >>>;
//---------------------------------------------------------------------

// Unit Generator Initial Values
    0.1 => vocoderOutput.gain;
    0.9 => adcOutput.gain;
    0.1 => line_synth.gain;
    filter_lpf.freq(0.999 * 10000);
    filter_hpf.freq(0.001 * 10000);

// Effect Values
    shift.mix(1.0);
    shift.shift(1.0);
    reverb.mix(0.05);
    chorus.mix(0.2);
    chorus.modDepth(0.0);
    
// Remove Zero Frequency Components to Reduce Distortion
    0.99999 => dcblock_mic.blockZero;
    0.99999 => dcblock_output.blockZero;

// Fast Fourier Transform Constants
    512 => int FFT_SIZE => fft_synth.size => fft_mic.size => ifft_output.size;
    FFT_SIZE => int WIN_SIZE;
    FFT_SIZE/32 => int HOP_SIZE; //64 is more full

// Define Hann Window for FFT
    Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => ifft_output.window;

// Define Spectrum Arrays
    // spectrum array for synth transform
    complex spectrum_synth[WIN_SIZE/2]; 
    // spectrum array for mic transform
    complex spectrum_mic[WIN_SIZE/2];
    // temp variables for complex to polar conversion
    polar temp_polar_mic, temp_polar_synth; 

// Define NoteEvent
class NoteEvent extends Event {
    float note;
}

NoteEvent on;
NoteEvent off;

// FFT Implementation
//--------------------------------------------------------------------
fun void vocode_filter() {
    while(true) {
        // take mic fft
        fft_mic.upchuck();
        // take synth fft
        fft_synth.upchuck(); 
        // retrieve results of mic transform
        fft_mic.spectrum(spectrum_mic); 
        // retrieve results of synth transform
        fft_synth.spectrum(spectrum_synth); 
        
        // for each value in the mic transform result, convert it from complex to
        // polar, apply it to the synth transform, and convert it back to complex:
        for( 0 => int i; i < spectrum_mic.cap(); i++ ) {
            spectrum_mic[i]$polar => temp_polar_mic;
            spectrum_synth[i]$polar => temp_polar_synth;
            // apply magnitude of mic to synth
            temp_polar_mic.mag => temp_polar_synth.mag; 
            // store result in altered synth transform
            temp_polar_synth$complex => spectrum_synth[i]; 
        }
        // take inverse transform of our new altered synth transform
        ifft_output.transform(spectrum_synth); 
        HOP_SIZE::samp => now;
    }
}
spork ~vocode_filter(); 
//--------------------------------------------------------------------

// Synthesizer Implementation
//--------------------------------------------------------------------


fun void synthvoice() {
    // don't connect to dac until we need it
    SqrOsc voice;
    Event off;
    float note;
    
    while (true) {
        on => now;
        <<< "NoteOn:", msg.data1, msg.data2 >>>;
        on.note => note;
        note => voice.freq;
        0.1 => voice.gain;
        voice => line_synth;
           
        if (onOrOff == 0) {
           <<< "NoteOff:", msg.data1, msg.data2 >>>;
           0.0 => voice.gain;
           voice =< line_synth;
        }
        
    }
}

// Run the Specified Iterations of the Synth
for (0 => int i; i < 4; i++) spork ~synthvoice();
//-------------------------------------------------------------------- 

while(true) {
    // wait on midi event
    min => now;
    // get the midimsg
    while(min.recv(msg)) {
        // print out midi data
        //<<< msg.data1, msg.data2, msg.data3 >>>;
        // catch only noteon
        if (msg.data1 == 144) {
            1 => onOrOff;
            // store midi note number
            Std.mtof(msg.data2) => on.note;
            // signal the event
            on.signal();
            // yield without advancing time to allow shred to run
            me.yield();
        } else {
            0 => onOrOff;
            off.signal();
            me.yield();
        }
    }
}
