MIX_TARGET ?= host
MIX_ENV ?= dev
BUILD_DIR ?= $(PWD)/_build/$(MIX_TARGET)/$(MIX_ENV)
C_SRC_DIR ?= $(PWD)/c_src
PRIV_DIR  ?= $(PWD)/priv

ALL :=
CLEAN :=
PHONY :=

ifeq ($(SKIP_ARDUINO_BUILD),)

ALL += farmbot_firmware
CLEAN += farmbot_firmware_clean

else

$(warning SKIP_ARDUINO_BUILD is set. No arduino assets will be built.)

endif

include $(C_SRC_DIR)/lua/lua.Makefile
include $(C_SRC_DIR)/build_calendar/build_calendar.Makefile

.DEFAULT_GOAL := all

.PHONY: all clean $(PHONY)

all: $(ALL)

clean: $(CLEAN)

farmbot_firmware:
	cd c_src/farmbot-arduino-firmware && make all BUILD_DIR=$(BUILD_DIR)/farmbot_firmware FBARDUINO_FIRMWARE_SRC_DIR=$(C_SRC_DIR)/farmbot-arduino-firmware/src BIN_DIR=$(PRIV_DIR)

farmbot_firmware_clean:
	cd c_src/farmbot-arduino-firmware && make clean BUILD_DIR=$(BUILD_DIR)/farmbot_firmware FBARDUINO_FIRMWARE_SRC_DIR=$(C_SRC_DIR)/farmbot-arduino-firmware/src BIN_DIR=$(PRIV_DIR)
