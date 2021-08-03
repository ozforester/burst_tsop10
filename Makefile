# Copyright (c) 2021 ozforester. All rights reserved.
# Use of this source code is goverened by a MIT license
# that can be found in the LICENSE file.


TARGET	 = burst
SOURCES := $(wildcard *.S)
OBJECTS  = $(SOURCES:.S=.o)

all:
	avr-gcc -DF_CPU=4000000 -Wall -mmcu=atmega8 -o ${TARGET} ${TARGET}.S
	avr-objcopy -O ihex ${TARGET} ${TARGET}.hex
	avr-size ${TARGET}.elf
	avr-size ${TARGET}.hex

flash:
	avrdude -c usbasp -p m8 -B 2 -U flash:w:${TARGET}.hex

clean:
	rm -f $(OBJECTS) $(TARGET).o $(TARGET).elf $(TARGET).hex
