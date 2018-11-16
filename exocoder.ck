/*
exocoder.ck by Kyle Laviana
Winter 2018

interval range: root - second fourth above root
note range: g2,a2,bflat2,c3,d3,e3,f3,g3,a3,bflat3,c4,d4,e4 (13)
equal temperament          
*/

// Synth Input
Gain line_synth => FFT fft_synth => blackhole;
// Mic Input
adc.left => PoleZero dcblock_mic => FFT fft_mic => blackhole;

// Processed Audio Output
IFFT ifft_output => PoleZero dcblock_output => PitShift shift => Chorus chorus => LPF lpf => HPF hpf => JCRev reverb => Gain vocoderOutput => Gain g => dac;
// Unprocessed Audio Output
adc => Gain adcOutput => dac;

// Midi Set-up
//---------------------------------------------------------------------
// number of the device to open (see: chuck --probe)
0 => int deviceNumber;
if (me.args()) me.arg(0) => Std.atoi => deviceNumber;
MidiIn min;
MidiMsg msg;
// open the device
if (!min.open(deviceNumber)) me.exit();
// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;
//---------------------------------------------------------------------

//Gametrak Set-up
//---------------------------------------------------------------------
// number of the joystick to open
0 => int joystick;
if( me.args() ) me.arg(0) => Std.atoi => joystick;
Hid trak;
HidMsg trakMsg;
// data structure for gametrak
class GameTrak {
    // timestamps
    time lastTime;
    time currTime;
    // previous axis data
    float lastAxis[6];
    // current axis data
    float axis[6];
}
GameTrak gt;
// open the joystick
if(!trak.openJoystick (joystick)) me.exit();
// print out joystick that was opened
<<< "joystick '" + trak.name() + "' ready", "" >>>;
 // Names for the joystick "channels" (trakMsg.channel).
    0 => int LEFT_X;
    1 => int LEFT_Y;
    2 => int LEFT_Z;
    3 => int RIGHT_X;
    4 => int RIGHT_Y;
    5 => int RIGHT_Z;
// z-axis deadzone
.012 => float DEADZONE;
spork ~gametrak();
spork ~processGametrakMotion();
//---------------------------------------------------------------------

// Unit Generator Initial Values
0.6 => vocoderOutput.gain;
0.8 => g.gain;
0.9 => adcOutput.gain;
0.1 => line_synth.gain;
lpf.freq(0.999 * 10000);
hpf.freq(0.001 * 10000);
0.05 => reverb.mix;

// Remove Zero Frequency Components to Reduce Distortion
0.999 => dcblock_mic.blockZero;
0.999 => dcblock_output.blockZero;

// Fast Fourier Transform Constants
600 => int FFT_SIZE => fft_synth.size => fft_mic.size => ifft_output.size;
FFT_SIZE => int WIN_SIZE;
FFT_SIZE/32 => int HOP_SIZE;

// Define Hann Window for FFT
Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => ifft_output.window;

// Define Spectrum Arrays
// spectrum array for synth transform
complex spectrum_synth[WIN_SIZE/2]; 
// spectrum array for mic transform
complex spectrum_mic[WIN_SIZE/2];
// temp variables for complex to polar conversion
polar temp_polar_mic, temp_polar_synth; 

// texture for vocoding
FMVoices baseOsc;
FMVoices intervalOsc;
// start at 0 gain
0 => baseOsc.gain;
0 => intervalOsc.gain;

// for tracking base & interval frequencies
float baseFreq;
float intervalFreq;
int intervalNumber;
// for tremolo effect
float t;

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

// infinite event loop
while (true) {
    // wait on event
    min => now;
    // get one or more messages
    while (min.recv(msg)) {
        // check for action type
        if (msg.data3 > 99) {   
            //<<< msg.data1, msg.data2, msg.data3 >>>;
            <<< "keyNum down: ", msg.data2 >>>;
            msg.data2 => int midiNumber;
            //set Base Note frequency and Gain
            if (findBaseFreq(midiNumber) > 0.0) {
                findBaseFreq(midiNumber) => baseFreq;
                baseFreq => baseOsc.freq;
                .5 => baseOsc.gain;
                baseOsc => line_synth;
                if (intervalNumber > 0) 0.4 => intervalOsc.gain; //OPTIONAL: intervalOsc won't operate without baseOsc
                //update interval frequency based on new base note
                findIntervalFreq(intervalNumber, baseFreq) => intervalFreq;
                intervalFreq => intervalOsc.freq;
                1 => baseOsc.noteOn;
            }
            //set Interval Note frequency and Gain
            if (midiNumber >= 101 && midiNumber <= 111) {
                findInterval(midiNumber) => intervalNumber;
                findIntervalFreq(intervalNumber, baseFreq) => intervalFreq;
                intervalFreq => intervalOsc.freq;
                .4 => intervalOsc.gain;
                intervalOsc => line_synth;
                1 => intervalOsc.noteOn;
            }
            // 10ms delay
            10::ms => now;
        } else {
            <<< "keyNum up: ", msg.data2 >>>;
            msg.data2 => int midiNumber;
            if (findBaseFreq(midiNumber) > 0.0) {
                0 => baseOsc.gain;
                baseOsc =< line_synth;
                0 => intervalOsc.gain; //OPTIONAL: intervalOsc won't operate without baseOsc
            }
            if (midiNumber >= 101 && midiNumber <= 110) {
                0 => intervalOsc.gain;
                intervalOsc =< line_synth;
                0 => intervalNumber;
            }
        }
    }
}

fun float findBaseFreq(int midiNumber) {
    float freq;
         if (midiNumber == 55)   98.00 => freq; //g2
    else if (midiNumber == 57) 110.00 => freq; //a2
    else if (midiNumber == 58) 116.54 => freq; //bflat2
    else if (midiNumber == 60)  130.81 => freq; //c3
    else if (midiNumber == 62) 146.83 => freq; //d3
    else if (midiNumber == 64) 164.81 => freq; //e3
    else if (midiNumber == 65) 174.61 => freq; //f3
    else if (midiNumber == 67) 196.00 => freq; //g3
    else if (midiNumber == 69) 220.00 => freq; //a3
    else if (midiNumber == 70) 233.08 => freq; //bflat3
    else if (midiNumber == 72) 261.63 => freq; //c4
    else if (midiNumber == 74) 293.66 => freq; //d4
    else if (midiNumber == 76) 329.63 => freq; //e4
    else return 0.0;
    return freq;  
}

fun float findIntervalFreq(int intervalNumber, float baseFreq) {
    float freq;
    int baseNote;
    //map frequencies to linear "base notes"
         if (baseFreq == 98.00)  1  => baseNote; //g2
    else if (baseFreq == 110.00) 2  => baseNote; //a2
    else if (baseFreq == 116.54) 3  => baseNote; //bflat2
    else if (baseFreq == 130.81) 4  => baseNote; //c3
    else if (baseFreq == 146.83) 5  => baseNote; //d3
    else if (baseFreq == 164.81) 6  => baseNote; //e3
    else if (baseFreq == 174.61) 7  => baseNote; //f3
    else if (baseFreq == 196.00) 8  => baseNote; //g3
    else if (baseFreq == 220.00) 9  => baseNote; //a3
    else if (baseFreq == 233.08) 10 => baseNote; //bflat3
    else if (baseFreq == 261.63) 11 => baseNote; //c4
    else if (baseFreq == 293.66) 12 => baseNote; //d4
    else if (baseFreq == 329.63) 13 => baseNote; //e4
    else return 0.0;
    //increase base note based on interval
    if (intervalNumber == 0) baseNote + 0 => baseNote;
    if (intervalNumber == 1) baseNote + 1 => baseNote;
    if (intervalNumber == 2) baseNote + 2 => baseNote;
    if (intervalNumber == 3) baseNote + 3 => baseNote;
    if (intervalNumber == 4) baseNote + 4 => baseNote;
    if (intervalNumber == 5) baseNote + 5 => baseNote;
    if (intervalNumber == 6) baseNote + 6 => baseNote;
    if (intervalNumber == 7) baseNote + 7 => baseNote;
    if (intervalNumber == 8) baseNote + 8 => baseNote;
    if (intervalNumber == 9) baseNote + 9 => baseNote;
    if (intervalNumber == 10) baseNote + 10 => baseNote;
    //map new base note back to frequency
    if (baseNote == 1)   98.00 => freq; //g2
    else if (baseNote == 2)  110.00 => freq; //a2
    else if (baseNote == 3)  116.54 => freq; //bflat2
    else if (baseNote == 4)  130.81 => freq; //c3
    else if (baseNote == 5)  146.83 => freq; //d3
    else if (baseNote == 6)  164.81 => freq; //e3
    else if (baseNote == 7)  174.61 => freq; //f3
    else if (baseNote == 8)  196.00 => freq; //g3
    else if (baseNote == 9)  220.00 => freq; //a3
    else if (baseNote == 10) 233.08 => freq; //bflat3
    else if (baseNote == 11) 261.63 => freq; //c4
    else if (baseNote == 12) 293.66 => freq; //d4
    else if (baseNote == 13) 329.63 => freq; //e4
    else if (baseNote == 14) 349.23 => freq; //f4
    else if (baseNote == 15) 392.00 => freq; //g4
    else if (baseNote == 16) 440.00 => freq; //a4
    else if (baseNote == 17) 466.16 => freq; //bflat4
    else if (baseNote == 18) 523.25 => freq; //c5
    else if (baseNote == 19) 587.33 => freq; //d5
    else if (baseNote == 20) 659.25 => freq; //e5
    else if (baseNote == 21) 698.46 => freq; //f5
    else if (baseNote == 22) 783.99 => freq; //g5
    else if (baseNote == 23) 880.00 => freq; //a5
    else return 0.0;
    return freq;  
}

fun int findInterval(int midiNumber) {
    int intervalNumber;
    if (midiNumber == 101) 0 => intervalNumber;
    if (midiNumber == 102) 1 => intervalNumber;
    if (midiNumber == 103) 2 => intervalNumber;
    if (midiNumber == 104) 3 => intervalNumber;
    if (midiNumber == 105) 4 => intervalNumber;
    //updated b/c button 6 not working
    //if (midiNumber == 106) 5 => intervalNumber;
    if (midiNumber == 107) 6 => intervalNumber;
    if (midiNumber == 108) 7 => intervalNumber;
    if (midiNumber == 109) 8 => intervalNumber;
    if (midiNumber == 110) 9 => intervalNumber;
    //if (midiNumber == 111) 10 => intervalNumber;
    if (midiNumber == 111) 5 => intervalNumber;
    return intervalNumber;  
}

// gametrack handling
fun void gametrak() {
    while (true) {
        // wait on HidIn as event
        trak => now;
        // messages received
        while (trak.recv(trakMsg)) {
            // joystick axis motion
            if (trakMsg.isAxisMotion()) {            
                // check which
                if (trakMsg.which >= 0 && trakMsg.which < 6){
                    // check if fresh
                    if (now > gt.currTime) {
                        // time stamp
                        gt.currTime => gt.lastTime;
                        // set
                        now => gt.currTime;
                    }
                    // save last
                    gt.axis[trakMsg.which] => gt.lastAxis[trakMsg.which];
                    // the z axes map to [0,1], others map to [-1,1]
                    if (trakMsg.which != LEFT_Z && trakMsg.which != RIGHT_Z ) { 
                        trakMsg.axisPosition => gt.axis[trakMsg.which]; 
                    } else {
                        1 - ((trakMsg.axisPosition + 1) / 2) - DEADZONE => gt.axis[trakMsg.which];
                        if( gt.axis[trakMsg.which] < 0 ) 0 => gt.axis[trakMsg.which];
                    }
                }
            }
        }
    }
}

fun void processGametrakMotion() {
    while (true) {
        // if strings are pulled out
        if (gt.axis[LEFT_Z] > DEADZONE && gt.axis[RIGHT_Z] > DEADZONE) {
            //gain controlled by x
            (gt.axis[RIGHT_X] + gt.axis[LEFT_X]) / 2 => float xAverage;
            (gt.axis[RIGHT_X] - xAverage) => float rawGainDepth;
            //<<< "gain: " + gainDepth >>>;
            //scale from 0-1 to .1 to .8
            (.1 + (1-.1)*(rawGainDepth-0)/(1-0)) => float gainDepth;
            gainDepth => g.gain;
            //tremolo controlled by y
            (gt.axis[LEFT_Y] + gt.axis[RIGHT_Y]) / 2 => float yAverage;
            (gt.axis[RIGHT_Y] - yAverage) => float rawTremoloDepth;
            //<<< "tremolo: " + rawTremoloDepth >>>;
            //scale from 0-1 to .05 to .2
            (.05 + (.4-.05)*(rawTremoloDepth-0)/(1-0)) => float tremoloDepth;
            .5 + ( Math.sin(t) + 1.0 )*tremoloDepth => vocoderOutput.gain;
             t + .004 => t;
            //if leftZ > rightZ, lpf
            if (gt.axis[LEFT_Z] > gt.axis[RIGHT_Z]) {
                (gt.axis[LEFT_Z] - gt.axis[RIGHT_Z]) => float rawLpfDepth;
                //<<< "lpf: " + lpfDepth >>>;
                //scale from 0-.5 to 1000 to 0
                (1000 + (0-1000)*(rawLpfDepth-0)/(.5-0)) => float lpfDepth;
                lpfDepth => lpf.freq;
            }
            //if rightZ > leftZ, hpf
            if (gt.axis[RIGHT_Z] > gt.axis[LEFT_Z]) {
                (gt.axis[RIGHT_Z] - gt.axis[LEFT_Z]) => float rawHpfDepth;
                //<<< "hpf: " + hpfDepth >>>;
                //scale from 0-.5 to 100 to 1000
                (100 + (1000-100)*(rawHpfDepth-0)/(.5-0)) => float hpfDepth;
                hpfDepth => hpf.freq;
            }
        }
        // .2ms delay
        .2::ms => now;
    }
}

