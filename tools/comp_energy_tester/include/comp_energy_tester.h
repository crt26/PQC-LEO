/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef COMP_ENERGY_TESTER_H
#define COMP_ENERGY_TESTER_H
#include "controller_api.h"
#include "controller_utils.h"
#include "oqs/oqs.h"

// Function for outputting the help message for the script, detailing the usage and available options
void output_help();

// Function for parsing the command line arguments passed to the comp_energy_tester script
void parse_args(int argc, char *argv[], int *display_welcome);

// Helper function for validating integer inputs
int int_checker(char *input, int *int_param, char *param_name);

// Function for configuring and initialising the selected control channel
int configure_controller(TestController *test_controller);

// Function for getting the testing options from the user to populate the TestParams struct
void get_test_options(TestParams *test_params);

// Function for performing the baseline energy measurements for a period of 10 seconds
void get_baseline(TestController *test_controller, TestParams *test_params);

// Function for testing a specific KEM algorithms energy usage by recording usage during keygen, encaps, and decaps operations
int test_kem(const char *method_name, TestController *test_controller, TestParams *test_params);

// Function for testing a specific digital signature algorithms energy usage by recording usage during keygen, sign, and verify operations
int test_sig(const char *method_name, TestController *test_controller, TestParams *test_params);

// Function for handling the overall testing process, including the setup, execution, and cleanup of the tests
int test_handler(TestController *test_controller);

#endif
