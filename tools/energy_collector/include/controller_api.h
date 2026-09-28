/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef CONTROL_SIGNALLER_H
#define CONTROL_SIGNALLER_H

#include "network_controller.h"
#include "serial_controller.h"

/**
 * Stores controller configuration and backend instances for control signalling.
 *
 * @param control_type Selected communication method (`"serial"` or `"network"`).
 * @param serial_controller Serial controller instance and configuration.
 * @param network_controller Network controller instance and configuration.
 */
typedef struct {
    char *control_type;
    SerialController serial_controller;
    NetworkController network_controller;
} TestController;

/**
 * Initialises the active controller backend based on the control type set in passed `TestController` struct.
 *
 * @param controller Pointer to the test controller instance.
 * @return 0 on success, -1 if the controller is NULL or the control type is unsupported.
 */ 
int controller_init(TestController *controller);

/**
 * Sends a control message using the selected communication method.
 *
 * @param controller Pointer to the test controller instance.
 * @param message Null-terminated message payload to send.
 * @return 0 on success, -1 if the control type is unsupported.
 */
int controller_send(TestController *controller, char *message);

/**
 * Receives a control message using the selected communication method.
 *
 * @param controller Pointer to the test controller instance.
 * @param message Buffer to store the received message.
 * @param message_size Size of the message buffer.
 * @return 0 on success, -1 if the control type is unsupported.
 */
int controller_receive(TestController *controller, char *message, size_t message_size);

/**
 * Closes the active controller backend based on the control type set in passed `TestController` struct.
 *
 * @param controller Pointer to the test controller instance.
 * @return 0 on success, -1 if the control type is unsupported.
 */
int controller_close(TestController *controller);

#endif