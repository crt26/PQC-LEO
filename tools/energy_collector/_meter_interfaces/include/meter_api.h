/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef METER_API_H
#define METER_API_H

#include <stddef.h>
#include "tc66c.h"

// Define the maximum string lengths for meter metadata fields
#define METER_NAME_MAX_LEN      16
#define METER_VERSION_MAX_LEN   16
#define METER_SERIAL_MAX_LEN    32

/**
 * Identifies the supported meter backend type.
 */
typedef enum {
    METER_TYPE_UNKNOWN = 0,
    METER_TYPE_TC66C
} MeterType;

/**
 * Stores the current reading values from the energy meter.
 *
 * @param name Meter model/name string.
 * @param version Meter firmware/version string.
 * @param serial_num Meter serial number string.
 * @param sample_runs Number of completed meter sample runs.
 * @param voltage Current voltage reading.
 * @param current Current current reading.
 * @param power Current power reading.
 * @param resistance Current resistance reading.
 * @param temperature Current temperature reading.
 * @param d_plus D+ line metric reported by the meter.
 * @param d_minus D- line metric reported by the meter.
 * @param mAh Current accumulated milliamp-hours (mAh) reading.
 * @param mWh Current accumulated milliwatt-hours (mWh) reading.
 */
typedef struct {
    char name[METER_NAME_MAX_LEN];
    char version[METER_VERSION_MAX_LEN];
    char serial_num[METER_SERIAL_MAX_LEN];
    unsigned int sample_runs;
    float voltage;
    float current;
    float power;
    float resistance;
    float temperature;
    float d_plus;
    float d_minus;
    unsigned int mAh;
    unsigned int mWh;
} MeterReading;

/**
 * Stores generic meter state for type-dispatched API calls.
 *
 * @param type Active meter backend type.
 * @param device_instance Backend-specific device instance pointer.
 */
typedef struct {
    MeterType type;
    void *device_instance;
} MeterDevice;

/**
 * Initialises a meter instance for the requested type and port.
 *
 * @param device Meter device wrapper to populate.
 * @param type Meter backend type to initialise.
 * @param serial_port_name Serial port name used by the backend.
 * @return 0 on success, -1 on invalid input, unsupported type, allocation failure,
 * or backend initialisation failure.
 */
int meter_init(MeterDevice *device, MeterType type, const char *serial_port_name);

/**
 * Sends a command message to the active meter device.
 *
 * @param device Initialised meter device wrapper.
 * @param message Null-terminated command payload.
 * @return 0 on success, -1 on invalid input, unsupported type, or backend send failure.
 */
int meter_send_cmd(MeterDevice *device, const char *message);

/**
 * Polls the active meter device and stores the reading values in the provided structure.
 *
 * @param device Initialised meter device wrapper.
 * @param reading Output structure for the latest reading values.
 * @return 0 on success, -1 on invalid input, unsupported type, or backend poll failure.
 */
int meter_poll(MeterDevice *device, MeterReading *reading);

/**
 * Closes the active meter device instance and releases associated meter resources.
 *
 * @param device Initialised meter device wrapper.
 * @return 0 on success, -1 on invalid input, unsupported type, or backend close failure.
 */
int meter_close(MeterDevice *device);

#endif
