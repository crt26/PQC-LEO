/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef CONTROL_SENDER_H
#define CONTROL_SENDER_H

#include "controller_api.h"
#include "controller_utils.h"
#include "meter_api.h"

// Struct for holding the controller interface configuration parameters
typedef struct {
    char *serial_port_name;
    char *local_ip;
    char *remote_ip;
    int local_port;
    int remote_port;
} ControllerInterfaces;

// Helper function for displaying the command line options
void output_help();

// Helper function for validating the format of a provided IP address
int validate_ip(char *ip_address);

// Parses the command line arguments passed to the program and handles test parameters extraction
int parse_args(TestParams *test_params, ControllerInterfaces *controller_interfaces, int argc, char *argv[]);

// Sets up the environment for control sender program, including controller instance initialisation
int setup_env(TestController *test_controller, ControllerInterfaces *controller_interfaces);

#endif
