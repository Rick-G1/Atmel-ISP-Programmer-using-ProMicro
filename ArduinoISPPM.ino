/******************************************************************************/
/*                                                                            */
/*      ArduinoISPPM -- Arduino programmer using Pro Micro Controller         */
/*                                                                            */
/*                     Copyright (c) 2021  Rick Groome                        */
/*      From original code from Randall Bohn  Copyright (c) 2008-2011         */
/*                                                                            */
/* Permission is hereby granted, free of charge, to any person obtaining a    */
/* copy of this software and associated documentation files (the "Software"), */
/* to deal in the Software without restriction, including without limitation  */
/* the rights to use, copy, modify, merge, publish, distribute, sublicense,   */
/* and/or sell copies of the Software, and to permit persons to whom the      */
/* Software is furnished to do so, subject to the following conditions:       */
/*                                                                            */
/* The above copyright notice and this permission notice shall be included in */
/* all copies or substantial portions of the Software.                        */
/*                                                                            */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR */
/* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,   */
/* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL    */
/* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER */
/* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    */
/* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER        */
/* DEALINGS IN THE SOFTWARE.                                                  */
/*                                                                            */
/*  PROCESSOR:  ATmega32U4       COMPILER: Arduino/GNU C for AVR Vers 1.8.5   */ 
/*  Written by: Randall Bohn 2011  Modified/Enhanced by Rick Groome 2021      */ 
/*                                                                            */
/******************************************************************************/

/*

Modified from original work for Pro Micro and my implementation as follows:    

1.  LED outputs now on different pins.  Removed simulated "heartbeat" and 
    replaced with simple on off at 1 sec interval. (Pin that the LED is wired 
    to on my adapter doesnt do AnalogWrite)

2.  Added target socket power on/off.  Output of this is hooked to the gate of 
    a P-CH FET, source hooked to power, drain hooked to VCC of target device. 
    Using ZXM62P02

3.  Added code to hold unused pins at GND. 
    Note: This is done with DIO primative instructions (eg DDRB,etc) and is set 
    up for Pro Micro module only.. Change (in "setup") if using a different 
    device. 

4.  Added code for JP2.  If JP2 is installed, then all DIO bits go to GND when 
    not programming (eg cold socket) and heartbeat lite blinks faster.  
    If JP2 is removed, then all target socket bits go to hi impedance state 
    when not programming and heartbeat lite blinks slower.

5.  Reworked the program LED so it doesnt consume more programming time when 
    PROG_FLICKER is true.  Now done with heartbeat and uses pmode as the 
    state... 0=off, 1=on, 2=blink.  Off when not running, On when reading, 
    Blinking when programming.

6.  Added JP3 to allow for faster programming time for devices that will 
    support it.  (Replaces SPI_CLOCK with SPI_SLOWCLK and SPI_FASTCLK)
    If JP3 is installed, use slower programming time without polling which 
    should be compatible with all devices, even with a slow clock. If JP3 is 
    removed then use faster programming time and poll device to wait for 
    programming page done (if device supports it).
    
7.  Added notes below... 

8.  Added 100KHz oscillator using Timer4 that can be used by user as clock 
    input to target micro, in case it's inadvertently programmed to Ext Clk or 
    crystal oscillator.  This signal can be applied to XTAL1 or CLKI to provide 
    clock to chip.  This signal (like others) can go to GND when not in use 
    (JP2 installed)(NOT in circuit format) or Hi-Z (JP2 NOT installed) 
    (in circuit).  Oscillator is completely implemented in hardware , w/ no 
    software required, other than to set up timer4 to an auto reloading PWM mode.

Checked with hardware SPI and BitBangedSPI.. Both work.

NOTE: (Took me a while to find this one) You should use avrdude programmer 
      type "arduino" (not "stk500v1" or "arduinoisp") because even though this 
      programmer looks like a stk500v1 it will not work without the usb DTR 
      signal going hi. (stk500v1 does not raise DTR).

Revision log: 
  1.0      12-20-18  REG   
    Initial implementation from work by Randall Bohn
    All of the changes listed above
  1.1      8-15-21   REG
    Reformatted for release 
  1.2      9-27-21   REG
    Move Digital 6 to Digital 4 so that Digital 6 can be used for oscillator out.
    Add 100KHz oscillator to Digital 6 (via timer4 OC4D output on PD7)
*/
// ArduinoISP
// Copyright (c) 2008-2011 Randall Bohn
// If you require a license, see
// http://www.opensource.org/licenses/bsd-license.php
//
// This sketch turns the Arduino into a AVRISP using the following Arduino pins:
//
// Pin 10 is used to reset the target microcontroller.
//
// By default, the hardware SPI pins MISO, MOSI and SCK are used to communicate	
// with the target. On all Arduinos, these pins can be found
// on the ICSP/SPI header:
//
//               MISO   °. .   5V (!) Avoid this pin on Due, Zero...
//               SCK     . .   MOSI
//               RESET   . .   GND
//
// On some Arduinos (Uno,...), pins MOSI, MISO and SCK are the same pins as
// digital pin 11, 12 and 13, respectively. That is why many tutorials instruct
// you to hook up the target to these pins. If you find this wiring more
// practical, have a define USE_OLD_STYLE_WIRING. This will work even when not
// using an Uno. (On an Uno this is not needed).
//
// Alternatively you can use any other digital pin by configuring
// software ('BitBanged') SPI and having appropriate defines for PIN_MOSI,
// PIN_MISO and PIN_SCK.
//
// IMPORTANT: When using an Arduino that is not 5V tolerant (Due, Zero, ...) as
// the programmer, make sure to not expose any of the programmer's pins to 5V.
// A simple way to accomplish this is to power the complete system (programmer
// and target) at 3V3.
//
// Put an LED (with resistor) on the following pins:
// 9: Heartbeat   - shows the programmer is running
// 8: Error       - Lights up if something goes wrong(use red if it makes sense)
// 7: Programming - In communication with the slave
//

#include "Arduino.h"
#undef SERIAL

#define INCLUDESOSCILLATOR     1

//#define DEBUG        true     // true to enable debug port and code
#define PROG_FLICKER true     // true to blink programming lite during write.

// Configure SPI clock (in Hz).
// E.g. for an ATtiny @ 128 kHz: the datasheet states that both the high and low
// SPI clock pulse must be > 2 CPU cycles, so take 3 cycles i.e. divide target
// f_cpu by 6:
//     #define SPI_CLOCK            (128000/6)
// A clock slow enough for an ATtiny85 @ 1 MHz, is a reasonable default:
//#define SPI_CLOCK 		(1000000/6)

#define SPI_SLOWCLK   (1000000/6)
#define SPI_FASTCLK   (10000000/6)    // clk/16 or 1.25MHz on ProMicro
//#define SPI_FASTCLK   (30000000/6)    // this is max speed (clk/4) (5Mhz)

// Select hardware or software SPI, depending on SPI clock.
// Currently only for AVR, 
// for other architectures (Due, Zero,...), hardware SPI is probably too 
// fast anyway.
#if defined(ARDUINO_ARCH_AVR)   // this is normally true
#if SPI_SLOWCLK > (F_CPU / 128)
#define USE_HARDWARE_SPI
#endif
#endif

//******************************************************************************
//               DIO pin assignments and use of HW or SW SPI   
//******************************************************************************

// Configure which pins to use:
// The standard pin configuration.
#ifndef ARDUINO_HOODLOADER2
#define RESET     10 	// Use pin 10 to reset the target rather than SS
#define LED_HB    7
#define LED_ERR   8
#define LED_PMODE 9
#define TVCC      18    // Output, Target VCC- (low to enable target VCC)
#define JP3       5     // Input,  JP3 jumper  (high[open] to use faster clock)

#if INCLUDESOSCILLATOR
#define JP2       4     // Input,  JP2 jumper  (high[open] to use as in-circuit 
                        //      programmer)(PD4)
#define OSCPIN    6     // Output, Pin for Oscillator output. (PD7)
#else
#define JP2       6     // Input,  JP2 jumper  (high[open] to use as in-circuit 
                        //			programmer)(PD7)
//#define LED_BUILTIN_RX 17   // not used... reference (predefined by arduino env)
//#define LED_BUILTIN_TX 30   // not used... reference (predefined by arduino env)
#endif                        
// Uncomment following line to use the old Uno style wiring
// (using pin 11, 12 and 13 instead of the SPI header) on Leonardo, Due...
// Define USE_OLD_STYLE_WIRING to use Sofware SPI, (and then use it only if it 
//   doesn't match hardwares pins)
//#define USE_OLD_STYLE_WIRING

#ifdef USE_OLD_STYLE_WIRING
#define PIN_MOSI	16 //11
#define PIN_MISO	14 //12
#define PIN_SCK		15 //13
// if defining pins, force the use software SPI
#undef USE_HARDWARE_SPI
#endif
#else
// HOODLOADER2 means running sketches on the ATmega16U2 serial converter chips
// on Uno or Mega boards. We must use pins that are broken out:
#define RESET     	4
#define LED_HB    	7
#define LED_ERR   	6
#define LED_PMODE 	5
#endif

// By default, use hardware SPI pins:
#ifndef PIN_MOSI
#define PIN_MOSI 	MOSI
#endif
#ifndef PIN_MISO
#define PIN_MISO 	MISO
#endif
#ifndef PIN_SCK
#define PIN_SCK 	SCK
#endif
// Force bitbanged SPI if not using the hardware SPI pins:
#if (PIN_MISO != MISO) ||  (PIN_MOSI != MOSI) || (PIN_SCK != SCK)
#undef USE_HARDWARE_SPI
#endif

//******************************************************************************
//                     Serial set up and support routines
//******************************************************************************

// Configure the serial port to use.
//
// Prefer the USB virtual serial port (aka. native USB port), if the Arduino 
// has one:
//   - it does not autoreset (except for the magic baud rate of 1200).
//   - it is more reliable because of USB handshaking.
//
// Leonardo and similar have an USB virtual serial port: 'Serial'.
// Due and Zero have an USB virtual serial port: 'SerialUSB'.
//
// On the Due and Zero, 'Serial' can be used too, provided you disable autoreset.
// To use 'Serial': #define SERIAL Serial

#ifdef SERIAL_PORT_USBVIRTUAL
#define SERIAL SERIAL_PORT_USBVIRTUAL
// define the following for UART on pins 1&2
//#define SERIAL Serial1
#else
#define SERIAL Serial
#endif

// Configure the baud rate:
#define BAUDRATE	19200

uint8_t getch() 
{
  while (!SERIAL.available());
  return SERIAL.read();
}

#ifdef DEBUG
//  Code to implement dprintf to printf to second serial port for debugging ....
//
// This hack is to get around C++ not being able to conditionally initializing 
// parts of a variable and producing the message
// Error:  "expected primary-expression before '.' token".
// So temporarily define it this way and hope that the definition of "FILE" 
// doesn't change soon.
#undef FDEV_SETUP_STREAM 
#define FDEV_SETUP_STREAM(p, g, f) { 0, 0, f, 0, 0, p, g, 0 } 
// If you don't use this, then you have to use fdevopen(&COM2put,0) in setup 
// instead, but it then includes malloc code which takes extra unneeded space.
int COM2putter( char c, FILE *t) { Serial1.write( c ); return 1; }
FILE COM2 = FDEV_SETUP_STREAM(COM2putter, NULL, _FDEV_SETUP_WRITE);
int dprintf(const char *fmt, ...)
{
  va_list a_list;  va_start( a_list, fmt );
  return vfprintf(&COM2,fmt,a_list);
}
#else 
#define dprintf(x,...) 
#endif


//******************************************************************************
//                      SPI settings and BitBangedSPI class
//******************************************************************************

#ifdef USE_HARDWARE_SPI
#include "SPI.h"
#else

#define SPI_MODE0 0x00

class SPISettings 
{
  public:
    // clock is in Hz
    SPISettings(uint32_t clock,uint8_t bitOrder,uint8_t dataMode):clock(clock) 
    {
      (void) bitOrder;
      (void) dataMode;
    };

  private:
    uint32_t clock;
    friend class BitBangedSPI;
};

class BitBangedSPI 
{
  public:
    void begin() {
      digitalWrite(PIN_SCK, LOW);    digitalWrite(PIN_MOSI, LOW);
      pinMode(PIN_SCK, OUTPUT);      pinMode(PIN_MOSI, OUTPUT);     
      pinMode(PIN_MISO, INPUT);
    }

    void beginTransaction(SPISettings settings) {
      pulseWidth = (500000 + settings.clock - 1) / settings.clock;
      if (pulseWidth == 0) pulseWidth = 1;
    }

    void end() {}

    uint8_t transfer (uint8_t b) {
      for (unsigned int i = 0; i < 8; ++i) {
        digitalWrite(PIN_MOSI, (b & 0x80) ? HIGH : LOW);
        digitalWrite(PIN_SCK, HIGH);
        delayMicroseconds(pulseWidth);
        b = (b << 1) | digitalRead(PIN_MISO);
        digitalWrite(PIN_SCK, LOW); // slow pulse
        delayMicroseconds(pulseWidth);
      }
      return b;
    }

  private:
    unsigned long pulseWidth;     // in microseconds
};

static BitBangedSPI SPI;

#endif

// macro to get two bytes as 16 bit integer
#define beget16(addr) (*addr * 256 + *(addr+1) )

//******************************************************************************
//
//                        Oscillator setup for Timer 4               
//
//******************************************************************************

void SetOscillator(byte prescale, int count)
// Set up timer4 to produce a 50% duty cycle square wave on PD7 (digital 6)
// This is a hardware produced output.. All we do is set it up and walk away 
// from it.   prescale is the prescaler value (1..15) , count is the OCR4C 
// count (2..1023)
{
  int x; 

  pinMode(OSCPIN, OUTPUT);                 // PD7 and OC4D
  PLLFRQ = 0x4A | ((0&3)<<4);         // Set PLLFRQ to input clock we want.
  TCCR4D=0; TCCR4A=0;       // Reset these to 0 (init() set it for PWM mode)
  TCCR4C = (1<<PWM4D)|(1<<COM4D0);    // Toggle on compare match (COMP D out)
  x=(count/2)-1;     // Set OCR4D/C to (1/2 of count)-1 for 50% duty cycle
  count-=1;  // Dont forget to subtract 1 from the count loaded into OCR4C !!
  TCNT4H /*upper OCR4C*/ =(count>>8); OCR4C=(count&0xFF); // set counter TOP value
  // Set OCR4d to 1/2 of svCNT value-1 for 50%;  
  TCNT4H /*upper OCR4B*/ =(x>>8); OCR4D=(x&0xFF); 
  // Finally set set prescaler and run 
  TCCR4B=(prescale)&0xF; 
}

//******************************************************************************
//
//                     Global Variables and setup / loop
//
//******************************************************************************

int error = 0;                // state of error lite
int pmode = 0;                // state of programming lite
bool fastmode;                // true if fast mode with polling.
unsigned int here;            // address for reading and writing, 
			      //   set by 'U' command
uint8_t buff[256];            // global block storage
static bool rst_active_high;  // is reset hi active or low active

// prototypes for forward reference
//void pulse(int pin, int times);
void heartbeat(void);
void avrisp(void);
void end_pmode();       


void setup() {
  // Set unused pins at GND (static zapping prevention)
  // For DDRx pins 1=output
  PORTF&=~0x73; DDRF&=~0x73;  // (A1,A2,A3,A4,A5)  (PORTF[3..2] do not exist)
  PORTD&=~0x53; DDRD&=~0x53;  // (D2,D3,D4,NUbit6) (Leave serial port PD2,PD3 usable)
  PORTC&=~0xC0; DDRC&=~0xC0;  // (D5,NUbit7)       (PORTC[5..0] do not exist)
  PORTB&=~0x80; DDRB&=~0x80;  // (NUbit7)
  // Set target VCC off
  pinMode(TVCC, OUTPUT);  digitalWrite(TVCC,HIGH);
  // Set JP2,JP3 as input with pullup
  pinMode(JP2,INPUT_PULLUP);   pinMode(JP3,INPUT_PULLUP);
#if INCLUDESOSCILLATOR
  pinMode(OSCPIN,INPUT_PULLUP);
#endif
  SERIAL.begin(BAUDRATE);
  // Set up the hardware for the LED's on the assembly.   
  pinMode(LED_PMODE, OUTPUT); digitalWrite(LED_PMODE,LOW);
  pinMode(LED_ERR,   OUTPUT); digitalWrite(LED_ERR,LOW);
  pinMode(LED_HB,    OUTPUT); digitalWrite(LED_HB,LOW);
#ifdef DEBUG
  Serial1.begin(19200);
#endif
  end_pmode();      // do a normal shutdown to set DIO pins as desired. 
}


void loop(void) 
{
  heartbeat();            // light the heartbeat LED and other LEDs
  if (SERIAL.available()) {  avrisp(); }
}

void heartbeat() {
  // This provides a heartbeat on pin 9,so you can tell the software is running.
  static unsigned long hb_time = 0;
  static unsigned long pgm_time = 0;
  unsigned long now = millis();
#if 0
  // Only bit 9 can do the PWM stuff for a realistic heartbeat (bit 7,8 cannot) 
  static uint8_t hbval = 128;
  static int8_t hbdelta = 8;
  if ((now - hb_time) < 40)  return;
  hb_time = now;
  if (hbval > 192) hbdelta = -hbdelta;
  if (hbval < 32) hbdelta = -hbdelta;
  hbval += hbdelta;
  analogWrite(LED_HB, hbval);
#else
  // just blink the LED... (fast if JP2 is low)
  if ((now - hb_time) >= (!digitalRead(JP2)?200:500)) 
  { hb_time = now;  digitalWrite(LED_HB, !digitalRead(LED_HB));  }
#endif
  // blink the programming LED, or turn it on/off based on pmode 
  if (pmode<2) 
    digitalWrite(LED_PMODE,pmode!=0);
  else
    if ((now - pgm_time) >= 50) 
    { pgm_time = now;  digitalWrite(LED_PMODE,!digitalRead(LED_PMODE));  }
  // is there an error?
  digitalWrite(LED_ERR, error!=0);
}


//******************************************************************************
//                      STK-500 v1 programmer code
//******************************************************************************

#define HWVER 2
#define SWMAJ 1
#define SWMIN 18

// STK Definitions
#define STK_OK      0x10
#define STK_FAILED  0x11
#define STK_UNKNOWN 0x12
#define STK_INSYNC  0x14
#define STK_NOSYNC  0x15
#define CRC_EOP     0x20 //ok it is a space...

                                // param values for a couple of AVR chips. 
typedef struct param {          // ATTiny4313  AtMega32u4
  uint8_t devicecode;           // 23           0
  uint8_t revision;             // 0            0
  uint8_t progtype;             // 0            0
  uint8_t parmode;              // 1            1
  uint8_t polling;              // 1            1
  uint8_t selftimed;            // 1            1
  uint8_t lockbytes;            // 1            1
  uint8_t fusebytes;            // 3            3
  uint8_t flashpoll;            // FF           0
  uint16_t eeprompoll;          // FFFF         0
  uint16_t pagesize;            // 40           80
  uint16_t eepromsize;          // 100          400
  uint32_t flashsize;           // 1000         FFFF8000
  // 2048 words 4096 bytes (4096=0x1000)
  // 16384 words 32768 bytes (=0x8000) (ffff ignored)
}
parameter;

parameter param;


void reset_target(bool reset) {
  digitalWrite(RESET, 
    ((reset && rst_active_high) || (!reset && !rst_active_high)) ? HIGH : LOW);
}


#if 0
// original PROG_FLICKER stuff
void prog_lamp(int state) 
{  if (PROG_FLICKER) { digitalWrite(LED_PMODE, state);  }}

#define PTIME 30
void pulse(int pin, int times) 
{
  do {
    digitalWrite(pin, HIGH);   delay(PTIME);
    digitalWrite(pin, LOW);    delay(PTIME);
  } while (times--);
}
#endif


uint8_t spi_transaction(uint8_t a, uint8_t b, uint8_t c, uint8_t d) 
{
  SPI.transfer(a);  SPI.transfer(b);  SPI.transfer(c);  
  return SPI.transfer(d);
}


void empty_reply() 
{
  if (CRC_EOP == getch()) 
  { SERIAL.print((char)STK_INSYNC);  SERIAL.print((char)STK_OK);  } 
  else  { error++;  SERIAL.print((char)STK_NOSYNC);  }
}


void breply(uint8_t b) 
{
  if (CRC_EOP == getch()) 
  {
    SERIAL.print((char)STK_INSYNC);    SERIAL.print((char)b);  
    SERIAL.print((char)STK_OK);
  } else   {
    error++;  SERIAL.print((char)STK_NOSYNC);
  }
}


void get_version(uint8_t c) 
{
  switch (c) {
    case 0x80:  breply(HWVER);   break;
    case 0x81:  breply(SWMAJ);   break;
    case 0x82:  breply(SWMIN);   break;
    case 0x93:  breply('S');     break;  // serial programmer 
    default:    breply(0);
  }
}


#ifdef DEBUG
void ShowParams(void)
{
  dprintf("Parameters\r\n");
  dprintf("Dev Code = %2X\r\n",(int) param.devicecode);
  dprintf("Revision = %2X\r\n",param.revision);
  dprintf("ProgType = %2X\r\n",param.progtype);
  dprintf("ParMode  = %2X\r\n",param.parmode);
  dprintf("Polling  = %2X\r\n",param.polling);
  dprintf("SelfTimed= %2X\r\n",param.selftimed);
  dprintf("LockBytes= %2X\r\n",param.lockbytes);
  dprintf("FuseBytes= %2X\r\n",param.fusebytes);
  dprintf("FlashPoll= %2X\r\n",param.flashpoll);
  dprintf("EpromPoll= %2X\r\n",param.eeprompoll);
  dprintf("PageSize = %2X\r\n",param.pagesize);
  dprintf("EESize   = %2X\r\n",param.eepromsize);
  dprintf("FlashSize= %2lX\r\n",param.flashsize);
}
#endif


void set_parameters() 
{
  // call this after reading parameter packet into buff[]
  param.devicecode = buff[0];
  param.revision   = buff[1];
  param.progtype   = buff[2];
  param.parmode    = buff[3];
  param.polling    = buff[4];
  param.selftimed  = buff[5];
  param.lockbytes  = buff[6];
  param.fusebytes  = buff[7];
  param.flashpoll  = buff[8];
  // ignore buff[9] (= buff[8])
  // following are 16 bits (big endian)
  param.eeprompoll = beget16(&buff[10]);
  param.pagesize   = beget16(&buff[12]);
  param.eepromsize = beget16(&buff[14]);

  // 32 bits flashsize (big endian)
  param.flashsize = buff[16] * 0x01000000
                    + buff[17] * 0x00010000
                    + buff[18] * 0x00000100
                    + buff[19];
  // AVR devices have active low reset, AT89Sx are active high
  rst_active_high = (param.devicecode >= 0xe0);
#ifdef DEBUG
  ShowParams();
#endif 
}


void WaitForReady(unsigned int MaxMs)
  // Wait for the chip to be ready or delay MaxMs, based on mode. 
{
  // approx 26 SPI transactions per mS at 1.66MHz SCK
  unsigned long starttime;  uint8_t rdy=1;  int lp=0;

  if (fastmode && param.polling)
  {
    starttime = millis();
    while (rdy&1 && (millis()-starttime) < MaxMs)
    { rdy=spi_transaction(0xf0,0x0,0x0,0x0); lp++; }
  }
  else delay(MaxMs);
}


void start_pmode() 
  // Set up the hardware to begin programming/reading part.
  // Turns on power, issues reset, sets up SPI hardware
{
  fastmode=!!digitalRead(JP3);   // Run fast?
  // Turn on power to the target device (and wait a bit for power/ext crystal 
  // to be stable)
  digitalWrite(TVCC, LOW);  
#if INCLUDESOSCILLATOR
  SetOscillator(1,160);  // 100KHz output on digital 6 (PD7)
  //delay(100);            // wait a little longer
#endif
  delay(250);
  // Reset target before driving PIN_SCK or PIN_MOSI
  // SPI.begin() will configure SS as output, so SPI master mode is selected.
  // We have defined RESET as pin 10, which for many Arduinos is not the SS pin.
  // So we have to configure RESET as output here,
  // (reset_target() first sets the correct level)
  reset_target(true);   pinMode(RESET, OUTPUT);

  SPI.begin();
  SPI.beginTransaction(SPISettings((fastmode?SPI_FASTCLK:SPI_SLOWCLK), 
                       MSBFIRST, SPI_MODE0));
  // See AVR datasheets, chapter "SERIAL_PRG Programming Algorithm":
  // Pulse RESET after PIN_SCK is low:
  digitalWrite(PIN_SCK, LOW);
  delay(20); // discharge PIN_SCK, value arbitrarily chosen
  reset_target(false);
  // Pulse must be minimum 2 target CPU clock cycles so 100 usec is ok for CPU
  // speeds above 20 KHz
  delayMicroseconds(100);
  reset_target(true);
  // Send the enable programming command:
  delay(50); // datasheet: must be > 20 msec
  spi_transaction(0xAC, 0x53, 0x00, 0x00);
  pmode = 1;
}


void end_pmode() 
  // Shut down programming mode.  Turn power off to the target chip, 
  // Shut down SPI, Put target pins to either Hi-z or ground. 
{
  SPI.end();
  // We're about to take the target out of reset so configure SPI pins as input
  pinMode(PIN_MOSI, INPUT_PULLUP); 
  pinMode(PIN_SCK,  INPUT_PULLUP); 
  // Set reset pin to whatever polarity is inactive, then switch to input
  reset_target(false);      pinMode(RESET, INPUT);
#if INCLUDESOSCILLATOR
  // Shut off timer (if it's running) and release the IO 
  TCCR4C=0; TCCR4B=0;              // Shut down the oscillator
  pinMode(OSCPIN, INPUT_PULLUP);   // Release output on the pin
#endif 
  pmode = 0;
  // Turn off power to the target device.
  digitalWrite(TVCC, HIGH);
  // if JP2 is installed then ground all the output bits. 
  if (!digitalRead(JP2))
  {
    digitalWrite(PIN_MOSI,LOW);  pinMode(PIN_MOSI,OUTPUT);
    digitalWrite(PIN_MISO,LOW);  pinMode(PIN_MISO,OUTPUT);
    digitalWrite(PIN_SCK,LOW);   pinMode(PIN_SCK,OUTPUT);
    digitalWrite(RESET,LOW);     pinMode(RESET,OUTPUT);
#if INCLUDESOSCILLATOR
    digitalWrite(OSCPIN,LOW);     pinMode(OSCPIN,OUTPUT);
#endif
  }
  // dprintf("MaxLoops=%d\r\n",MaxLoops);
}


void fill(int n) 
{
  for (int x = 0; x < n; x++) {  buff[x] = getch(); }
}


void universal() 
{
  uint8_t ch;
  fill(4);   ch = spi_transaction(buff[0], buff[1], buff[2], buff[3]);
  breply(ch);
}


void flash(uint8_t hilo, unsigned int addr, uint8_t data) 
{
  if (pmode) pmode=2;       // Prog lite blink 
  spi_transaction(0x40 + 8 * hilo, addr >> 8 & 0xFF, addr & 0xFF, data);
}


uint8_t flash_read(uint8_t hilo, unsigned int addr) 
{
  if (pmode) pmode=1;       // Prog lite solid on 
  return spi_transaction(0x20 + hilo * 8, (addr >> 8) & 0xFF, addr & 0xFF, 0);
}


void commit(unsigned int addr) 
{
  //if (PROG_FLICKER) { prog_lamp(LOW); }
  spi_transaction(0x4C, (addr >> 8) & 0xFF, addr & 0xFF, 0);
  //if (PROG_FLICKER) { delay(PTIME); prog_lamp(HIGH);  } else
  // Need to have some minimum delay... // 1 is not enough... 2 seems fine. 
  WaitForReady(30);  // 30 simulates the old prog_flicker time
}


unsigned int current_page() 
{
  if (param.pagesize == 32)  { return here & 0xFFFFFFF0; }
  if (param.pagesize == 64)  { return here & 0xFFFFFFE0; }
  if (param.pagesize == 128) { return here & 0xFFFFFFC0; }
  if (param.pagesize == 256) { return here & 0xFFFFFF80;  }
  return here;
}


void write_flash(int length) 
{
  fill(length);
  if (CRC_EOP == getch()) 
  {
    SERIAL.print((char) STK_INSYNC);   
    SERIAL.print((char) write_flash_pages(length));
  } else {
    error++;  SERIAL.print((char) STK_NOSYNC);
  }
}


uint8_t write_flash_pages(int length) 
{
  int x = 0;
  unsigned int page = current_page();
  while (x < length) {
    if (page != current_page()) {  commit(page);  page = current_page(); }
    flash(LOW, here, buff[x++]);
    flash(HIGH, here, buff[x++]);
    here++;
  }
  commit(page);
  return STK_OK;
}


#define EECHUNK (32)
uint8_t write_eeprom(unsigned int length) 
{
  // here is a word address, get the byte address
  unsigned int start = here * 2;
  unsigned int remaining = length;
  if (pmode) pmode=2;       // Prog lite blink 
  if (length > param.eepromsize) {  error++;  return STK_FAILED; }
  while (remaining > EECHUNK) {
    write_eeprom_chunk(start, EECHUNK);
    start += EECHUNK;  remaining -= EECHUNK;
  }
  write_eeprom_chunk(start, remaining);
  return STK_OK;
}


// write (length) bytes, (start) is a byte address
uint8_t write_eeprom_chunk(unsigned int start, unsigned int length) 
{
  // this writes byte-by-byte, page writing may be faster (4 bytes at a time)
  fill(length);
  // prog_lamp(LOW);   // original PROG_FLICKER stuff
  for (unsigned int x = 0; x < length; x++) {
    unsigned int addr = start + x;
    spi_transaction(0xC0, (addr >> 8) & 0xFF, addr & 0xFF, buff[x]);
  WaitForReady(45);  // was originally delay(45)
  }
  // prog_lamp(HIGH);    // original PROG_FLICKER stuff
  return STK_OK;
}


void program_page() 
{
  char result = (char) STK_FAILED;
  unsigned int length = 256 * getch();
  length += getch();
  char memtype = getch();
  // flash memory @here, (length) bytes
  if (memtype == 'F') {  write_flash(length);   return;  }
  if (memtype == 'E') {
    result = (char)write_eeprom(length);
    if (CRC_EOP == getch()) {
      SERIAL.print((char) STK_INSYNC);
      SERIAL.print(result);
    } else {
      error++;
      SERIAL.print((char) STK_NOSYNC);
    }
    return;
  }
  SERIAL.print((char)STK_FAILED);
  return;
}


char flash_read_page(int length) 
{
  for (int x = 0; x < length; x += 2) {
    uint8_t low = flash_read(LOW, here);
    SERIAL.print((char) low);
    uint8_t high = flash_read(HIGH, here);
    SERIAL.print((char) high);
    here++;
  }
  return STK_OK;
}


char eeprom_read_page(int length) 
{
  // here again we have a word address
  int start = here * 2;
  if (pmode) pmode=1;  // Prog lite solid on 
  for (int x = 0; x < length; x++) {
    int addr = start + x;
    uint8_t ee = spi_transaction(0xA0, (addr >> 8) & 0xFF, addr & 0xFF, 0xFF);
    SERIAL.print((char) ee);
  }
  return STK_OK;
}


void read_page() 
{
  char result = (char)STK_FAILED;
  int length = 256 * getch();
  length += getch();
  char memtype = getch();
  if (CRC_EOP != getch()) {
    error++;
    SERIAL.print((char) STK_NOSYNC);
    return;
  }
  SERIAL.print((char) STK_INSYNC);
  if (memtype == 'F') result = flash_read_page(length);
  if (memtype == 'E') result = eeprom_read_page(length);
  SERIAL.print(result);
}


void read_signature() 
{
  if (CRC_EOP != getch()) {
    error++;  
    SERIAL.print((char) STK_NOSYNC);
    return;
  }
  SERIAL.print((char) STK_INSYNC);
  uint8_t high = spi_transaction(0x30, 0x00, 0x00, 0x00);    SERIAL.print((char) high);
  uint8_t middle = spi_transaction(0x30, 0x00, 0x01, 0x00);  SERIAL.print((char) middle);
  uint8_t low = spi_transaction(0x30, 0x00, 0x02, 0x00);     SERIAL.print((char) low);
  SERIAL.print((char) STK_OK);
}


//******************************************************************************
//                   STK-500 v1 Command Interpreter
//******************************************************************************

void avrisp() 
{
  uint8_t ch = getch();
  switch (ch) {
    case '0':       // signon
      error = 0;
      empty_reply();
      break;
    case '1':       // get programmer type
      if (getch() == CRC_EOP) {
        SERIAL.print((char) STK_INSYNC);
        SERIAL.print("AVR ISP");
        SERIAL.print((char) STK_OK);
      }
      else {
        error++;
        SERIAL.print((char) STK_NOSYNC);
      }
      break;
    case 'A':       // get version 
      get_version(getch());
      break;
    case 'B':       // get parameters 
      fill(20);
      set_parameters();
      empty_reply();
      break;
    case 'E':       // extended parameters - ignore for now
      fill(5);
      empty_reply();
      break;
    case 'P':       //0x50  Start programming mode
      if (!pmode) start_pmode();
      empty_reply();
      break;
    case 'Q':       //0x51  End programming mode
      error = 0;
      end_pmode();
      empty_reply();
      break;
    case 0x75:      // 'u' STK Read Signature
      read_signature();
      break;

    case 'U':       // set address (word)
      here = getch();
      here += 256 * getch();
      empty_reply();
      break;
    case 0x60:      //STK_PROG_FLASH (ignore)
      getch(); // low addr
      getch(); // high addr
      empty_reply();
      break;
    case 0x61:      //STK_PROG_DATA (ignore)
      getch(); // data
      empty_reply();
      break;
    case 0x64:      //STK_PROG_PAGE
      program_page();
      break;
    case 0x74:      //STK_READ_PAGE 't'
      read_page();
      break;
    case 'V':       //0x56
      universal();
      break;
    // expecting a command, not CRC_EOP
    // this is how we can get back in sync
    case CRC_EOP:
      error++;
      SERIAL.print((char) STK_NOSYNC);
      break;
    // anything else we will return STK_UNKNOWN
    default:
      error++;
      if (CRC_EOP == getch())
        SERIAL.print((char)STK_UNKNOWN);
      else
        SERIAL.print((char)STK_NOSYNC);
  }
}

