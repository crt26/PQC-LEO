/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef COLLECTOR_H
#define COLLECTOR_H

#include "meter_api.h"
#include "controller_api.h"
#include "controller_utils.h"

// Define the control commands passed from the control listener to the collection thread
typedef enum {
    CONTROL_GETREADY,
    CONTROL_START,
    CONTROL_STOP,
    CONTROL_END
} ControlAction;

// Store the command and the file and polling settings supplied by GETREADY
typedef struct {
    ControlAction action;
    char output_filepath[1024];
    useconds_t polling_rate;
} ControlCommand;

// Store the metrics file and the starting values for the current operation on the collection thread
typedef struct {
    FILE *metrics_file;
    useconds_t polling_rate;
    unsigned int start_mAh;
    unsigned int start_mWh;
    struct timespec start_time;
} EnergyCollection;

// Struct for defining the format of the meter type options presented to the user during setup
typedef struct {
    int option_number;
    const char *name;
    MeterType type;
} MeterTypeOption;

// Array of supported meter type options for user selection during setup
static const MeterTypeOption supported_meter_types[] = {
    {1, "TC66C", METER_TYPE_TC66C}
};

// Function for outputting the help message for the collector scripts, displaying the usage, options, and their descriptions
void output_help();

// Function for parsing the command line arguments passed to the collector script
void parse_args(int argc, char *argv[], int *display_welcome, int *prompt_for_result_dir);

// Function for configuring the test controller used for sending and receiving control signals
int configure_controller(TestController *test_controller);

// Function for prompting the user to select the energy meter type to use for testing
static MeterType prompt_meter_type(void);

// Sets up the environment for energy metrics collection
int setup_env(TestController *test_controller, MeterDevice *meter_device, int prompt_for_result_dir);

// Handles parsing the incoming GETREADY message and preparing the metrics file
int get_ready_parser(char *message, ControlCommand *get_ready_command);

// Control listener thread function for handling incoming control signals
void *control_listener_thread(void *arg);

// Energy metrics collection thread function for polling the energy device
void *collect_energy_metrics_thread(void *arg);

#endif
