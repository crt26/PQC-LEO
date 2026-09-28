/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/
#ifndef CONTROLLER_UTILS_H
#define CONTROLLER_UTILS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "controller_api.h"

/**
 * Holds control and test metadata extracted from CLI input or GETREADY messages.
 *
 * @param control_method Control communication method ("serial" or "network").
 * @param control_type Numeric control message type identifier used by internal logic.
 * @param test_type Test category/name.
 * @param test_algs Tested algorithm/s.
 * @param total_runs Total number of runs configured for the test.
 * @param run_num Run number for the current test.
 * @param iterations Number of iterations configured for the run.
 * @param polling_rate Energy polling rate in milliseconds.
 */
typedef struct {
    char *control_method;
    int control_type;
    char *test_type;
    const char *test_algs;
    int total_runs;
    int run_num;
    int iterations;
    float polling_rate;
} TestParams;

/**
 * Lists available serial ports and prompts the user to select one.
 *
 * @return Allocated serial port string, which the caller must free, or NULL on failure.
 */
char* list_serial_ports();

/**
 * Prompt the user for an IPv4 address, validate it, and store it in the
 * supplied buffer.
 *
 * @param ip_address Output buffer where the validated IPv4 address string will be written.
 * @param ip_address_len Length of the `ip_address` buffer in bytes.
 */
void get_ip_address(char *ip_address, size_t ip_address_len);

/**
 * Check if the specified network port is available for use by attempting to bind a test 
 * socket to it. The function will check for both TCP and UDP protocols based on the provided 
 * protocol name.
 *
 * @param port_number Port number to test for availability (1-65535).
 * @param protocol Name of the protocol to check the port for ("TCP" or "UDP").
 * @return 0 if bind succeeded (port available), -1 on failure.
 */
int check_port_availability(int port_number, const char *protocol);

/**
 * Prompt the user to enter a network port number and validate that it is within the valid 
 * range (1-65535). The function will continue to prompt until a valid port number is entered.
 *
 * @param port_number Output pointer where the validated port number will be stored.
 */
void get_port_number(int *port_number);

/**
 * Parses a control message and extracts command and message fields from it.
 *
 * @param message Input message buffer to parse.
 * @param command String value for the expected command to be contained in the message.
 * @param message_elements Output array for parsed message tokens.
 * @param message_elements_size Size of the `message_elements` array in bytes.
 * @return 0 on success, -1 on parse/validation failure.
 */
int message_parser(char *message, char *command, char **message_elements, size_t message_elements_size);

/**
 * Formats a GETREADY message using the supplied test parameters.
 *
 * @param test_params Input test parameter structure.
 * @param get_ready_message Output GETREADY message buffer.
 * @param message_size Size of the GETREADY message buffer.
 * @return 0 on success, -1 on formatting failure.
 */
int get_ready_formatter(TestParams *test_params, char *get_ready_message, size_t message_size);

/**
 * Sends/receives control messages on the testing device based on the configured control method.
 *
 * @param test_controller Controller instance used for signal operations.
 * @param test_params Test parameters to be sent to the collector machine for test configuration.
 * @return 0 on success, -1 on command/response handling failure.
 */
int control_handler(TestController *test_controller, TestParams *test_params);

#endif
