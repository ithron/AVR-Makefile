######
# This Makefile has been written by Stefan Reinhold <development@ithron.de>
# and was released to Public Domain.
#
# In order to program the fuse bytes you have to download the 
# AVRFuseExtractor script from
# 	http://github.com/ithron/AVRFuseExtractor
#

##################################################################
# Targets:
#   all
#		perform build, lst, hex and size 
#
#   build
#		compile the sources and create a .elf file
#
#   lst
#		create an extended assembly listing (.lst)
#
#   hex
#		create flash and eeprom images from the .elf file
#
#   size
#		print statistics for the binary image
#
#   program
#		write the flash and eeprom ROM images onto the device
#
#   install
#		performs program and wfuse
#
#   fuse
#		extracts and prnts the fuse configuration form the .elf file
#
#   rfuse
#		read the fuse bytes from the device
#
#   wfuse
#		write the fuse bytes (from the .elf file) onto the device
#
#   clean
#		clean all working files
#
#   erase
#		perform a chip erase
#

########################
# PROJECT CONFIGURATION
########################

# The pr	oject name
PROJECT		= SampleProject

# Optimization level (0,1,2,s,3)
OPTIMIZE		= s

# Additional definitions
DEFS 			= 

# Warning level to use
WARN			= -Wall

# Debugger options
DEBUG			= -g

# C source files (.c)
C_SOURCES	= SampleProject.c \
				  SampleProjectFuses.c

# Assemby source files (.S)
ASM_SOURCES	=

# Additional libraries to use
LIBS			=

# Additional flags for the C compiler
CFLAGS		=

# Additional flags for the assembler
ASFLAGS		=

# Additional flags for the linker
LDFLAGS		=

# The C standard to use
STD			= gnu99


###########################
# CONTROLLER CONFIGURATION
###########################

# The microcontroller to use
MCU			= attiny84
# The controller's frequency in Herz
FREQ			= 8000000

###########################
# PROGRAMMER CONFIGURATION
###########################

PROGRAMMER	= avrispmkII
PORT			= usb
PROG_MCU		= t84

# Additional arguments for avrdude
AVRDUDE_ARGS = 

##########################
# TOOLCHAIN CONFIGURATION
##########################

# Path and/or names for the toolchain's tools
CC				= avr-gcc
AS				= avr-as
LD				= avr-ld
OBJCOPY		= avr-objcopy
OBJDUMP		= avr-objdump
SIZE			= avr-size
RM				= rm -f
EXTFUSE		= $(SHELL) extractfuses.sh
AVRDUDE		= avrdude

##########
# TARGETS
##########

nullstring := 
space := $(nullstring) 
QUOTED_SOURCE_ROOT=$(subst $(space),\ ,$(SOURCE_ROOT))
QUOTED_OBJECT_FILE_DIR=$(subst $(space),\ ,$(OBJECT_FILE_DIR))

all: build lst hex size
hex : fhex ehex
install: program wfuse

lst: $(PROJECT).lst
fhex: $(PROJECT).hex
ehex: $(PROJECT)_eeprom.hex
build: $(PROJECT).elf

######

AVRDUDE_ARGS += -p $(PROG_MCU) -c $(PROGRAMMER) -P $(PORT)

CFLAGS		+= $(DEBUG) $(WARN) -O$(OPTIMIZE) -mmcu=$(MCU) \
					-std=$(STD) $(DEFS) -I. \
					-DF_CPU=$(FREQ)UL \
					-MD -MP -MF .dep/$(@F).d # Generate dependencies
					
ASFLAGS		+= -mmcu=$(MCU) -DF_CPU=$(FREQ)UL -I. \
					-Wa,-adhlns=$(<:.S=.lst),-gstabs
					
LDFLAGS		+= -Wl,-Map,$(PROJECT).map,--cref # Create a map file

OBJECTS		= $(C_SOURCES:.c=.o) $(ASM_SOURCES:.S=.o)

%.lst: %.elf
	$(OBJDUMP) -h -S $< > $@

size: $(PROJECT).elf
	@echo
	@$(SIZE) $<

fuse: $(PROJECT).elf
	@echo "low `$(EXTFUSE) l $<`"
	@echo "high `$(EXTFUSE) h $<`"
	@echo "extended `$(EXTFUSE) e $<`"

%.hex: %.elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@
	
%_eeprom.hex: %.elf
	$(OBJCOPY) -j .eeprom --change-section-lma .eeprom=0 -O ihex $< $@ \
	|| { echo empty $@ not generated; exit 0; }

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $(subst $(space),\ ,$(SOURCE_ROOT)/$<)
	
%.o: %.S
	$(CC) $(ASFLAGS) -c -o $@ $(subst $(space),\ ,$(SOURCE_ROOT)/$<)
	
$(PROJECT).elf: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^ $(LIBS)
	
clean:
	$(RM) $(OBJECTS)
	$(RM) $(PROJECT).elf
	$(RM) $(PROJECT).hex
	$(RM) $(PROJECT)_eeprom.hex
	$(RM) $(PROJECT).lst
	$(RM) $(PROJECT).map
	$(RM) -r .dep
	
wfuse: $(PROJECT).elf
	$(AVRDUDE) -p $(PROG_MCU) -c $(PROGRAMMER) -P $(PORT) `$(EXTFUSE) avrdude $<`

rfuse:
	$(AVRDUDE) -p $(PROG_MCU) -c $(PROGRAMMER) -P $(PORT) \
		-U lfuse:r:-:h -U hfuse:r:-:h -U efuse:r:-:h
		
program: $(PROJECT).hex $(PROJECT)_eeprom.hex
	$(AVRDUDE) $(AVRDUDE_ARGS) \
		-U flash:w:$(PROJECT).hex \
		-U eeprom:w:$(PROJECT)_eeprom.hex
	
erase:
	$(AVRDUDE) $(AVRDUDE_ARGS) -e

# Include dependency files
-include $(shell mkdir .dep 2>/dev/null) $(wildcard .dep/*)
