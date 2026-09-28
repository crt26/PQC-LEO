/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO meter abstraction layer for energy data
collection. It provides a unified API to initialise supported meter devices,
send control commands, poll live readings, and close device resources. 
Operations are handled by meter type, where device-specific logic can be 
called while maintaining a consistent interface.

If adding new energy meter backends, please refer to the current API frontend
implementation in this script. Additional documentation can be found in the 
PQC-LEO repository site.

*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "meter_api.h"
#include "tc66c.h"

//-------------------------------------------------------------------------------------------------------------------------------
int meter_init(MeterDevice *device, MeterType type, const char *com_port_name) {
    /*  Function for initialising a energy meter device. It configures the device based on its type and the provided COM port name. 
        It will check the device type and initialise the appropriate device instance based on what is currently supported. 
        New device instances can be added here as needed. */

    // Ensure that passed values are valid before proceeding
    if (device == NULL || com_port_name == NULL) {
        fprintf(stderr, "[ERROR] - Invalid parameters for meter initialisation.\n");
        return -1;
    }

    // Set a default device type of unknown until the type is checked and set properly
    device->type = METER_TYPE_UNKNOWN;

    // Check which meter type is being initialised and call the relevant initialisation function
    switch (type) {

        case METER_TYPE_TC66C: {
            
            // Create and instance of the TC66C_Device struct
            TC66C_Device *tc66c_device = malloc(sizeof(TC66C_Device));
            if (tc66c_device == NULL) {
                fprintf(stderr, "[ERROR] - Failed to allocate memory for TC66C device instance.\n");
                return -1;
            }
            
            // Configure the TC66C port configurations
            *tc66c_device = (TC66C_Device){
                .com_port = NULL,
                .aes_ctx = NULL,
                .baudrate = 115200,
                .data_bits = 8,
                .parity = SP_PARITY_NONE,
                .stop_bits = 2,
                .flow_control = SP_FLOWCONTROL_NONE,
            };

            // Assign the TC66C device instance and type in the generic MeterDevice struct
            device->device_instance = tc66c_device;
            device->type = METER_TYPE_TC66C;

            // Initialise the TC66C device using the provided COM port name
            if (tc66c_init(device->device_instance, com_port_name) != 0) {
                fprintf(stderr, "[ERROR] - Failed to initialise TC66C device.\n");
                free(tc66c_device);
                return -1;
            }
            
            return 0;
        
        }

        default: {
            fprintf(stderr, "[ERROR] - Unsupported meter type for initialisation.\n");
            return -1;
        }

    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int meter_send_cmd(MeterDevice *device, const char *message) {
    /*  Function for sending a command to an energy meter device. It will check the device type and call the 
        relevant command sending function. */

    // Ensure that the device instance has been initialised properly and that the message pointer is valid before proceeding
    if (device == NULL || device->device_instance == NULL || message == NULL) {
        fprintf(stderr, "[ERROR] - Invalid parameters for meter command sending.\n");
        return -1;
    }

    // Check the type of meter device and call the relevant command sending function
    switch (device->type) {

        case METER_TYPE_TC66C: {

            // Cast generic stored pointer back to a TC66C device pointer
            TC66C_Device *tc66c_device = (TC66C_Device *)device->device_instance;

            // Send the command to the TC66C device
            if (tc66c_send_cmd(tc66c_device, message) != 0) {
                fprintf(stderr, "[ERROR] - Failed to send command to TC66C device.\n");
                return -1;
            }

            return 0;

        }

        default:
            fprintf(stderr, "[ERROR] - Unsupported meter type for command sending.\n");
            return -1;

    }

}

//-------------------------------------------------------------------------------------------------------------------------------
int meter_poll(MeterDevice *device, MeterReading *poll_data) {
    /*  Function for polling an energy meter device for readings. It will check the device type and call the 
        relevant polling function to retrieve the current readings from the device. The retrieved data is stored
        in the provided poll_data struct. */

    // Ensure that the device instance has been initialised properly and that the poll_data pointer is valid before proceeding
    if (device == NULL || device->device_instance == NULL || poll_data == NULL) {
        fprintf(stderr, "[ERROR] - Invalid parameters for meter polling.\n");
        return -1;
    }

    // Check the type of meter device and call the relevant polling function
    switch (device->type) {

        case METER_TYPE_TC66C: {

            // Cast generic stored pointer back to a TC66C device pointer
            TC66C_Device *tc66c_device = (TC66C_Device *)device->device_instance;

            // Temporary TC66C-specific poll data
            TC66C_PollData tc66c_poll_data;

            // Poll the TC66C device
            if (tc66c_poll(tc66c_device, &tc66c_poll_data) != 0) {
                fprintf(stderr, "[ERROR] - Failed to poll TC66C device.\n");
                return -1;
            }

            // Copy over the relevant data from the TC66C_PollData struct to the MeterReading struct
            strncpy(poll_data->name, tc66c_poll_data.name, METER_NAME_MAX_LEN - 1);
            poll_data->name[METER_NAME_MAX_LEN - 1] = '\0';

            strncpy(poll_data->version, tc66c_poll_data.Version, METER_VERSION_MAX_LEN - 1);
            poll_data->version[METER_VERSION_MAX_LEN - 1] = '\0';

            strncpy(poll_data->serial_num, tc66c_poll_data.serial_num, METER_SERIAL_MAX_LEN - 1);
            poll_data->serial_num[METER_SERIAL_MAX_LEN - 1] = '\0';

            poll_data->sample_runs = tc66c_poll_data.sample_runs;
            poll_data->voltage = tc66c_poll_data.voltage;
            poll_data->current = tc66c_poll_data.current;
            poll_data->power = tc66c_poll_data.power;
            poll_data->resistance = tc66c_poll_data.resistance;
            poll_data->temperature = (float)tc66c_poll_data.temp;
            poll_data->d_plus = tc66c_poll_data.D_plus;
            poll_data->d_minus = tc66c_poll_data.D_minus;
            poll_data->mAh = tc66c_poll_data.G0_mAh + tc66c_poll_data.G1_mAh;
            poll_data->mWh = tc66c_poll_data.G0_mWh + tc66c_poll_data.G1_mWh;

            return 0;

        }

        default:
            fprintf(stderr, "[ERROR] - Unsupported meter type.\n");
            return -1;

    }

}

//-------------------------------------------------------------------------------------------------------------------------------
int meter_close(MeterDevice *device) {
    /*  Function for closing a connection instance with a energy meter device. It will check the device type and call the 
        relevant closing function to release the device resources. */

    // Ensure that the device instance has been initialised properly before proceeding
    if (device == NULL || device->device_instance == NULL) {
        fprintf(stderr, "[ERROR] - Invalid parameters for meter closing.\n");
        return -1;
    }

    // Check the type of meter device and call the relevant closing function
    switch (device->type) {

        case METER_TYPE_TC66C: {

            // Cast generic stored pointer back to a TC66C device pointer
            TC66C_Device *tc66c_device = (TC66C_Device *)device->device_instance;

            // Close the TC66C device
            if (tc66c_close(tc66c_device) != 0) {
                fprintf(stderr, "[ERROR] - Failed to close TC66C device.\n");
                return -1;
            }

            // Free the allocated memory for the TC66C device instance
            free(tc66c_device);
            device->device_instance = NULL;
            device->type = METER_TYPE_UNKNOWN;

            return 0;

        }

        default:
            fprintf(stderr, "[ERROR] - Unsupported meter type for closing.\n");
            return -1;

    }

    return 0;

}