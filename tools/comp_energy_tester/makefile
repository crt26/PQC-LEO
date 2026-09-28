CC := gcc
OPENSSL_PATH ?= /usr
OPENSSL_CRYPTO := -lcrypto
ifneq ($(OPENSSL_PATH),/usr)
OPENSSL_CRYPTO := $(firstword $(wildcard $(OPENSSL_PATH)/lib64/libcrypto.so) $(wildcard $(OPENSSL_PATH)/lib/libcrypto.so))
endif
LIBOQS_PATH ?= ../../lib/liboqs/build

CFLAGS := -Wall -Wextra -std=c11 \
	-Iinclude \
	-I../energy_collector/include \
	-I../energy_collector/_meter_interfaces/include \
	-I$(OPENSSL_PATH)/include \
	-I$(LIBOQS_PATH)/include

BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
BIN_DIR := $(BUILD_DIR)/bin

ENERGY_LIBS := \
	../energy_collector/build/lib/libcontroller_api.a \
	../energy_collector/build/lib/libmeter_api.a

LIBOQS_LIB_DIR := $(LIBOQS_PATH)/lib
LDFLAGS := -L$(LIBOQS_LIB_DIR) -L$(OPENSSL_PATH)/lib
LIBOQS_LDLIBS := -loqs -lserialport $(OPENSSL_CRYPTO) -lpthread
COMMON_LDLIBS := -lpthread

COMP_ENERGY_TESTER_OBJS := \
	$(OBJ_DIR)/comp_energy_tester.o

.PHONY: all clean dirs clean-objs

all: dirs $(BIN_DIR)/comp_energy_tester
	$(MAKE) clean-objs

dirs:
	mkdir -p $(OBJ_DIR) $(BIN_DIR)

$(OBJ_DIR)/comp_energy_tester.o: src/comp_energy_tester.c
	$(CC) $(CFLAGS) -c $< -o $@

$(BIN_DIR)/comp_energy_tester: $(COMP_ENERGY_TESTER_OBJS)
	$(CC) $^ $(ENERGY_LIBS) $(LDFLAGS) $(LIBOQS_LDLIBS) -o $@

clean-objs:
	rm -rf $(OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)