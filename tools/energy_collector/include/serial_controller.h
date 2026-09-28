/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef SERIAL_CONTROLLER_H
#define SERIAL_CONTROLLER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libserialport.h>

/**
 * Stores the serial controller configuration and active port handle.
 *
 * @param control_port_name Serial port identifier.
 * @param control_port Open libserialport handle for the configured control port.
 * @param baudrate Serial baud rate used for communication.
 * @param data_bits Number of data bits per frame.
 * @param parity Parity mode used by the serial interface.
 * @param stop_bits Number of stop bits per frame.
 * @param flow_control Flow control mode used by the serial interface.
 */
typedef struct {
    const char *control_port_name;
    struct sp_port* control_port;
    int baudrate;
    int data_bits;
    int parity;
    int stop_bits;
    int flow_control;
} SerialController;

/**
 * Initialises the serial controller with the configured port settings.
 *
 * @param serial_controller Pointer to the serial controller instance.
 * @return 0 on success, -1 if initialisation fails.
 */
int serial_controller_init(SerialController *serial_controller);

/**
 * Receives a control message from the configured serial port.
 * Reads bytes until a newline or carriage return is received. The delimiter is
 * not included in the copied output string.
 *
 * @param serial_controller Pointer to the serial controller instance.
 * @param message Output buffer for the received message text.
 * @param message_size Size of message in bytes (must be greater than 0).
 * @return 0 on success, -1 if the controller is invalid or an error occurs during reading.
 */
int serial_controller_receiver(SerialController *serial_controller, char *message, size_t message_size);

/**
 * Sends a control message through the configured serial port.
 * The payload is transmitted exactly as provided; no newline or carriage return
 * terminator is appended by this function.
 *
 * @param serial_controller Pointer to the serial controller instance.
 * @param message Null-terminated message payload to send.
 * @return 0 on success, -1 if the controller is invalid, the message is empty,
 * or the write operation fails.
 *
 */
int serial_controller_send(SerialController *serial_controller, char *message);

/**
 * Closes the serial controller and releases associated resources.
 *
 * @param serial_controller Pointer to the serial controller instance.
 * @return 0 on success, -1 if the controller is invalid.
 */
int serial_controller_close(SerialController *serial_controller);

#endif
