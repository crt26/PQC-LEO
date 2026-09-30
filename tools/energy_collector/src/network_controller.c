/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO network controller backend for control
signalling over UDP. It initialises local and remote socket endpoints,
receives control messages from the configured socket, transmits outbound
commands to the remote endpoint, and performs clean shutdown of socket
resources when testing operations complete.
*/

#include <network_controller.h>

//-------------------------------------------------------------------------------------------------------------------------------
int network_controller_init(NetworkController *network_controller) {
    /*  Function for initialising the network controller with the specified UDP settings. It will create the UDP socket, 
        configure the local and remote addresses, and bind the socket to the local address and port. It will return any 
        errors encountered during this process. */

    // Ensure that the network controller struct is valid
    if (network_controller == NULL) {
        fprintf(stderr, "[ERROR] - The NetworkController instance is NULL\n");
        return -1;
    }

    // Create the UDP socket
    network_controller->udp_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (network_controller->udp_socket < 0) {
        fprintf(stderr, "[ERROR] - Unable to create UDP socket\n");
        return -1;
    }

    // Configure the local listening address
    memset(&network_controller->local_addr, 0, sizeof(network_controller->local_addr));
    network_controller->local_addr.sin_family = AF_INET;
    network_controller->local_addr.sin_port = htons(network_controller->local_port);
    inet_pton(AF_INET, network_controller->local_address, &network_controller->local_addr.sin_addr);

    // Bind the local address and port to the socket
    bind(network_controller->udp_socket, (struct sockaddr *)&network_controller->local_addr, sizeof(network_controller->local_addr));

    // Configure the remote address
    memset(&network_controller->remote_addr, 0, sizeof(network_controller->remote_addr));
    network_controller->remote_addr.sin_family = AF_INET;
    network_controller->remote_addr.sin_port = htons(network_controller->remote_port);
    inet_pton(AF_INET, network_controller->remote_address, &network_controller->remote_addr.sin_addr);

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int network_controller_receiver(NetworkController *network_controller, char *message, size_t message_size) {
    /*  Function for receiving messages from the UDP socket. It will receive a message from the socket and store it in the 
        provided buffer. It will return any errors encountered during this process. */

    // Ensure that the network controller struct is valid
    if (network_controller == NULL) {
        fprintf(stderr, "[ERROR] - The NetworkController instance is NULL\n");
        return -1;
    }

    // Receive the message from the UDP socket
    ssize_t bytes_received = recvfrom(network_controller->udp_socket, message, message_size - 1, 0, NULL, NULL);
    if (bytes_received < 0) {
        fprintf(stderr, "[ERROR] - Failed to receive message\n");
        return -1;
    }

    // Remove any trailing newline characters from the received message
    while (bytes_received > 0 && (message[bytes_received - 1] == '\n' || message[bytes_received - 1] == '\r')) {
        message[--bytes_received] = '\0';
    }

    // Null terminate the received message
    message[bytes_received] = '\0';

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int network_controller_send(NetworkController *network_controller, char *message) {
    /*  Function for sending messages through the UDP socket. It will send a message to the remote address and return any 
        errors encountered during this process. */

    // Ensure that the network controller struct is valid
    if (network_controller == NULL) {
        fprintf(stderr, "[ERROR] - The NetworkController instance is NULL\n");
        return -1;
    }

    // Ensure that the message is not empty
    if (message[0] == '\0') {
        fprintf(stderr, "[ERROR] - The command message is empty\n");
        return -1;
    }

    // Send the message to the remote address
    sendto(network_controller->udp_socket, message, strlen(message), 0, (struct sockaddr *)&network_controller->remote_addr, sizeof(network_controller->remote_addr));

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int network_controller_close(NetworkController *network_controller) {
    /*  Function for closing the UDP socket and cleaning up the network controller. It will close the socket if it is open and 
        reset the socket file descriptor. It will return any errors encountered during this process. */
    
    // Ensure that the network controller struct is correctly initialised
    if (!network_controller){
        return -1;
    }

    // Close the UDP socket if it is open
    if (network_controller->udp_socket >= 0) {
        close(network_controller->udp_socket);
        network_controller->udp_socket = -1;
    }
    
    return 0;
    
}
