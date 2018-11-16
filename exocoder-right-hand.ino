// 250aRightHand.ino by Kyle Laviana
// a final project for Music 250A
// 3/1/18

#include <WiFi.h>
#include <WiFiClient.h>
#include <WiFiUdp.h>

#include "AppleMidi.h"

char ssid[] = "NETGEAR21"; //  your network SSID (name)
char pass[] = "windylotus544";    // your network password (use for WPA, or use as key for WEP)

unsigned long t0 = millis();
bool isConnected = false;

APPLEMIDI_CREATE_INSTANCE(WiFiUDP, AppleMIDI); // see definition in AppleMidi_Defs.h

//Analog Pin A4 (GPIO #36) being used for thumb FSR
#define ANALOG_PIN_A4 36

//midiChannel, doesn't matter
byte midiChannel = 1;

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void setup() {
  // Serial communications and wait for port to open:
  Serial.begin(115200);
  while (!Serial) {
    ; // wait for serial port to connect. Needed for Leonardo only
  }
  Serial.print(F("Getting IP address..."));
  WiFi.disconnect(true);                                      // Clear Wifi Credentials
  WiFi.persistent(false);                                     // Avoid to store Wifi configuration in Flash
  WiFi.mode(WIFI_STA);                                        // Ensure WiFi mode is Station 
  WiFi.begin(ssid, pass);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(F("."));
  }
  Serial.println(F(""));
  Serial.println(F("WiFi connected"));
  Serial.println();
  Serial.print(F("IP address is "));
  Serial.println(WiFi.localIP());
  Serial.println(F("OK, now make sure you an rtpMIDI session that is Enabled"));
  Serial.print(F("Add device named Arduino with Host/Port "));
  Serial.print(WiFi.localIP());
  Serial.println(F(":5004"));
  Serial.println(F("Then press the Connect button"));
  Serial.println(F("Then open a MIDI listener (eg MIDI-OX) and monitor incoming notes"));

  // Create a session and wait for a remote host to connect to us
  AppleMIDI.begin("test");
  AppleMIDI.OnConnected(OnAppleMidiConnected);
  AppleMIDI.OnDisconnected(OnAppleMidiDisconnected);
  AppleMIDI.OnReceiveNoteOn(OnAppleMidiNoteOn);
  AppleMIDI.OnReceiveNoteOff(OnAppleMidiNoteOff);

  //Initializing digital pins on left side of board
  pinMode(26, INPUT);
  pinMode(25, INPUT);
  pinMode(34, INPUT);
  pinMode(39, INPUT);
  //note--skipping pin #36 b/c using as analog for fsr
  pinMode(4, INPUT);
  pinMode(21, INPUT);

  //Initializing digital pins on right side of board
  pinMode(13, INPUT);
  pinMode(12, INPUT);
  pinMode(27, INPUT);
  pinMode(33, INPUT);
  pinMode(15, INPUT);
  pinMode(32, INPUT);
  pinMode(14, INPUT);
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void loop() {
  // Listen to incoming notes
  // (dont cáll delay(1000) as it will stall the pipeline)
  AppleMIDI.run();
  
  /*
  //analog reading of thumb fsr
  int sensorValueA4 = analogRead(ANALOG_PIN_A4); // retrieving sensor value on A4
  int sensorValueA4Converted = sensorValueA4*127/4095;
  byte midiValueA4 = (byte) sensorValueA4Converted; // cast conversion int --> byte
  //Serial.println(midiValue1);
  if (midiValueA4 > 5) {
    Serial.println(midiValueA4);
    AppleMIDI.noteOn(36, midiValueA4, midiChannel);
  }
  */
  
  //First number is the GPIO Pin #, second number is the Midi Note Number it will use
  //Check for button presses at gpio inputs on left side of board
  checkForButtonPress(26, 55); //A0
  checkForButtonPress(25, 57); //A1
  checkForButtonPress(34, 58); //A2
  checkForButtonPress(39, 60); //A3
  //note--skipping pin #36 b/c using as analog for fsr //A4
  checkForButtonPress(4, 62);  //A5
  checkForButtonPress(21, 64); //21

  //Check for button presses at gpio inputs on right side of board
  checkForButtonPress(13, 65); //13
  checkForButtonPress(12, 67); //12
  checkForButtonPress(27, 69); //27
  checkForButtonPress(33, 70); //33
  checkForButtonPress(15, 72); //15
  checkForButtonPress(32, 74); //32
  checkForButtonPress(14, 76); //14
}

void checkForButtonPress(int pinNumber, int midiNumber) {
  if (digitalRead(pinNumber) == HIGH) {
    AppleMIDI.noteOn(midiNumber, 100, midiChannel); //note, velocity, channel
    Serial.print(pinNumber);
    Serial.println(": GPIO Pin # Released");
    while (digitalRead(pinNumber) == HIGH) {
      delay(20); //20ms delay
    }
    AppleMIDI.noteOff(midiNumber, 0, midiChannel); //note, velocity, channel
    Serial.print(pinNumber);
    Serial.println(": GPIO Pin # Released");
  }
}

// ====================================================================================
// Event handlers for incoming MIDI messages
// ====================================================================================

// -----------------------------------------------------------------------------
// rtpMIDI session. Device connected
// -----------------------------------------------------------------------------
void OnAppleMidiConnected(uint32_t ssrc, char* name) {
  isConnected  = true;
  Serial.print(F("Connected to session "));
  Serial.println(name);
}

// -----------------------------------------------------------------------------
// rtpMIDI session. Device disconnected
// -----------------------------------------------------------------------------
void OnAppleMidiDisconnected(uint32_t ssrc) {
  isConnected  = false;
  Serial.println(F("Disconnected"));
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void OnAppleMidiNoteOn(byte channel, byte note, byte velocity) {
  Serial.print(F("Incoming NoteOn from channel:"));
  Serial.print(channel);
  Serial.print(F(" note:"));
  Serial.print(note);
  Serial.print(F(" velocity:"));
  Serial.print(velocity);
  Serial.println();
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------
void OnAppleMidiNoteOff(byte channel, byte note, byte velocity) {
  Serial.print(F("Incoming NoteOff from channel:"));
  Serial.print(channel);
  Serial.print(F(" note:"));
  Serial.print(note);
  Serial.print(F(" velocity:"));
  Serial.print(velocity);
  Serial.println();
}
