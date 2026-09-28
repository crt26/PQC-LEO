CC := gcc
AR := ar
OPENSSL_PATH ?= /usr

CFLAGS := -Wall -Wextra -std=c11 -Iinclude -I_meter_interfaces/include -I$(OPENSSL_PATH)/include
LDFLAGS := -L$(OPENSSL_PATH)/lib
LDLIBS := -lserialport -lcrypto -lpthread

BUILD_DIR := build
OBJ_DIR := $(BUILD_DIR)/obj
LIB_DIR := $(BUILD_DIR)/lib
BIN_DIR := $(BUILD_DIR)/bin

CONTROLLER_LIB := $(LIB_DIR)/libcontroller_api.a
METER_LIB := $(LIB_DIR)/libmeter_api.a

CONTROLLER_LIB_OBJS := \
	$(OBJ_DIR)/controller_api.o \
	$(OBJ_DIR)/network_controller.o \
	$(OBJ_DIR)/serial_controller.o \
	$(OBJ_DIR)/controller_utils.o

METER_SRCS := $(sort $(wildcard _meter_interfaces/src/*.c))
METER_LIB_OBJS := $(patsubst _meter_interfaces/src/%.c,$(OBJ_DIR)/meter_%.o,$(METER_SRCS))

COLLECTOR_OBJ := $(OBJ_DIR)/collector.o
CONTROL_SENDER_OBJ := $(OBJ_DIR)/control_sender.o

.PHONY: all libs bins clean dirs clean-objs

all: libs bins
	$(MAKE) clean-objs

libs: dirs $(CONTROLLER_LIB) $(METER_LIB)

bins: dirs $(BIN_DIR)/collector $(BIN_DIR)/control_sender

dirs:
	mkdir -p $(OBJ_DIR) $(LIB_DIR) $(BIN_DIR)

$(OBJ_DIR)/collector.o: src/collector.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/control_sender.o: src/control_sender.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/controller_api.o: src/controller_api.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/network_controller.o: src/network_controller.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/serial_controller.o: src/serial_controller.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/controller_utils.o: src/controller_utils.c
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJ_DIR)/meter_%.o: _meter_interfaces/src/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(CONTROLLER_LIB): $(CONTROLLER_LIB_OBJS)
	$(AR) rcs $@ $^

$(METER_LIB): $(METER_LIB_OBJS)
	rm -f $@
	$(AR) rcs $@ $^

$(BIN_DIR)/collector: $(COLLECTOR_OBJ) $(CONTROLLER_LIB) $(METER_LIB)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BIN_DIR)/control_sender: $(CONTROL_SENDER_OBJ) $(CONTROLLER_LIB)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

clean-objs:
	rm -rf $(OBJ_DIR)

clean:
	rm -rf $(BUILD_DIR)
