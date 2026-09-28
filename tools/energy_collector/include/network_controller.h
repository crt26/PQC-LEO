/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef NETWORK_CONTROLLER_H
#define NETWORK_CONTROLLER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>

/**
 * Stores the network controller configuration and socket endpoint state.
 *
 * @param tcp_socket TCP socket descriptor (used when TCP mode is enabled).
 * @param udp_socket UDP socket descriptor used for message transport.
 * @param local_port Local port used for bind/listen operations.
 * @param remote_port Remote port used for outbound messages.
 * @param net_protocol Selected protocol string ("TCP" or "UDP").
 * @param local_address Local IPv4 address string.
 * @param remote_address Remote IPv4 address string.
 * @param local_addr Parsed local socket address structure.
 * @param remote_addr Parsed remote socket address structure.
 */
typedef struct {
    int tcp_socket;
    int udp_socket;
    int local_port;
    int remote_port;
    const char* net_protocol;
    const char* local_address;
    const char* remote_address;
    struct sockaddr_in local_addr;
    struct sockaddr_in remote_addr;
} NetworkController;

/**
 * Initialises the network controller with the configured socket settings.
 *
 * @param network_controller Pointer to the network controller instance.
 * @return 0 on success, -1 if initialisation fails.
 */
int network_controller_init(NetworkController *network_controller);

/**
 * Receives a control message from the configured network socket.
 *
 * @param network_controller Pointer to the network controller instance.
 * @param message Output buffer for the received message.
 * @param message_size Size of `message` in bytes.
 * @return 0 on success, -1 if receive fails.
 */
int network_controller_receiver(NetworkController *network_controller, char *message, size_t message_size);

/**
 * Sends a control message to the configured remote device.
 *
 * @param network_controller Pointer to the network controller instance.
 * @param message Null-terminated message payload to send.
 * @return 0 on success, -1 if send fails.
 */
int network_controller_send(NetworkController *network_controller, char *message);

/**
 * Closes the network controller and releases socket resources.
 *
 * @param network_controller Pointer to the network controller instance.
 * @return 0 on success, -1 if close fails.
 */
int network_controller_close(NetworkController *network_controller);

#endif