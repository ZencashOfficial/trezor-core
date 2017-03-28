.PHONY: vendor

JOBS=4
MAKE=make -j $(JOBS)

BOOTLOADER_BUILD_DIR=micropython/bootloader/build
LOADER_BUILD_DIR=micropython/loader/build
FIRMWARE_BUILD_DIR=micropython/firmware/build

TREZORHAL_PORT_OPTS=FROZEN_MPY_DIR=src DEBUG=1
UNIX_PORT_OPTS=MICROPY_FORCE_32BIT=1 MICROPY_PY_BTREE=0 MICROPY_PY_TERMIOS=0 MICROPY_PY_FFI=0 MICROPY_PY_USSL=0 MICROPY_SSL_AXTLS=0 DEBUG=1
CROSS_PORT_OPTS=MICROPY_FORCE_32BIT=1

## help commands:

help: ## show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m  make %-20s\033[0m %s\n", $$1, $$2} /^##(.*)/ {printf "\033[33m%s\n", substr($$0, 4)}' $(MAKEFILE_LIST)

## dependencies commands:

vendor: ## update git submodules
	# git submodule update --init

res: ## update resources
	./tools/res_collect

## emulator commands:

run: ## run unix port
	cd src ; ../vendor/micropython/unix/micropython

emu: ## run emulator
	./emu.sh

## test commands:

test: ## run unit tests
	cd tests ; ./run_tests.sh

testpy: ## run selected unit tests from python-trezor
	cd tests ; ./run_tests_python_trezor.sh

## build commands:

build: build_firmware build_bootloader build_loader build_unix build_cross ## build all

build_firmware: vendor res build_cross ## build firmware with frozen modules
	$(MAKE) -f Makefile.firmware $(TREZORHAL_PORT_OPTS)

build_bootloader: vendor ## build bootloader
	$(MAKE) -f Makefile.bootloader $(TREZORHAL_PORT_OPTS)

build_loader: vendor ## build loader
	$(MAKE) -f Makefile.loader $(TREZORHAL_PORT_OPTS)

build_unix: vendor ## build unix port
	$(MAKE) -f ../../../micropython/unix/Makefile -C vendor/micropython/unix $(UNIX_PORT_OPTS)

build_cross: vendor ## build mpy-cross port
	$(MAKE) -C vendor/micropython/mpy-cross $(CROSS_PORT_OPTS)

## clean commands:

clean: clean_firmware clean_bootloader clean_loader clean_unix clean_cross ## clean all

clean_firmware: ## clean firmware build
	$(MAKE) -f Makefile.firmware clean $(TREZORHAL_PORT_OPTS)

clean_bootloader: ## clean bootloader build
	$(MAKE) -f Makefile.bootloader clean $(TREZORHAL_PORT_OPTS)

clean_loader: ## clean loader build
	$(MAKE) -f Makefile.loader clean $(TREZORHAL_PORT_OPTS)

clean_unix: ## clean unix build
	$(MAKE) -f ../../../micropython/unix/Makefile -C vendor/micropython/unix clean $(UNIX_PORT_OPTS)
	# workaround for relative paths containing ../.. in unix Makefile
	rm -rf vendor/micropython/micropython

clean_cross: ## clean mpy-cross build
	$(MAKE) -C vendor/micropython/mpy-cross clean $(CROSS_PORT_OPTS)

## flash commands:

flash_firmware: ## flash firmware using st-flash
	st-flash write $(FIRMWARE_BUILD_DIR)/firmware.bin 0x8000000

flash_bootloader: ## flash bootloader using st-flash
	st-flash write $(BOOTLOADER_BUILD_DIR)/bootloader.bin 0x8000000

flash_loader: ## flash loader using st-flash
	st-flash write $(LOADER_BUILD_DIR)/loader.bin 0x8000000

## openocd debug commands:

openocd: ## start openocd which connects to the device
	openocd -f interface/stlink-v2.cfg -f target/stm32f4x.cfg

gdb: ## start remote gdb session which connects to the openocd
	arm-none-eabi-gdb $(FIRMWARE_BUILD_DIR)/firmware.elf -ex 'target remote localhost:3333'
