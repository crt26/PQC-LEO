/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT

This script implements the PQC-LEO TC66C meter backend used by the energy
collector. It initialises the TC66C serial connection and AES decryption
context, sends supported device commands, polls encrypted live measurement
packets and maps them into structured readings, and closes all serial and 
crypto resources on shutdown.

Valid commands that can be sent to the TC66C include:
Command   Mode    Response Size (Bytes)   Meaning
-------   ----    ---------------------   -------
query     All     4                       Query mode ('firm' or 'boot')
getva     Normal  192                     Poll readings (ret: pacX).
gtrec     Normal  Variable                Get recording.
lastp     Normal  0                       Previous page.
nextp     Normal  0                       Next page.
rotat     Normal  0                       Rotate screen.
update    Boot    5                       Prepare to upload firmware (returns 'uprdy').

^ from - https://sigrok.org/wiki/RDTech_TC66C
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libserialport.h>
#include "tc66c.h"

//-------------------------------------------------------------------------------------------------------------------------------
int tc66c_init(TC66C_Device *tc66c_device, const char *serial_port_name) {
    /*  Function for initialising the TC66C device instance. It will open the specified serial port and configure it with the
        specified parameters contained in the device instance struct. */

    // Get the serial port by name using the passed serial_port_name and store it in the device instance
    if (sp_get_port_by_name(serial_port_name, &tc66c_device->serial_port) != SP_OK) {
        fprintf(stderr, "Error: Unable to find port %s\n", serial_port_name);
        return -1;
    }

    // Open the serial port for read/write
    if (sp_open(tc66c_device->serial_port, SP_MODE_READ_WRITE) != SP_OK) {
        fprintf(stderr, "Error: Unable to open port %s\n", serial_port_name);
        return -1;
    }

    // Configure the serial port
    sp_set_baudrate(tc66c_device->serial_port, 115200);
    sp_set_bits(tc66c_device->serial_port, 8);
    sp_set_parity(tc66c_device->serial_port, SP_PARITY_NONE);
    sp_set_stopbits(tc66c_device->serial_port, 2);
    sp_set_flowcontrol(tc66c_device->serial_port, SP_FLOWCONTROL_NONE);

    // Allocate the AES cipher context used to decrypt TC66C measurement packets.
    tc66c_device->aes_ctx = EVP_CIPHER_CTX_new();
    if (tc66c_device->aes_ctx == NULL) {

        // Output the error message and clean up the serial port before returning
        fprintf(stderr, "Error: Failed to allocate AES decryption context\n");
        sp_close(tc66c_device->serial_port);
        sp_free_port(tc66c_device->serial_port);
        return -1;

    }

    // Initialise the AES-256-ECB decryption context with the TC66C static key.
    if (EVP_DecryptInit_ex(tc66c_device->aes_ctx, EVP_aes_256_ecb(), NULL, TC66C_STATIC_KEY, NULL) != 1) {

        // Output the error message to the terminal 
        fprintf(stderr, "Error: Failed to initialise AES decryption context\n");

        // Clean up the AES context and serial port before returning
        EVP_CIPHER_CTX_free(tc66c_device->aes_ctx);
        tc66c_device->aes_ctx = NULL;
        sp_close(tc66c_device->serial_port);
        sp_free_port(tc66c_device->serial_port);
        return -1;

    }

    // As the TC66C data packets are fixed-size raw AES blocks, disable PKCS#7 padding
    EVP_CIPHER_CTX_set_padding(tc66c_device->aes_ctx, 0);

    return 0;
    
}

//-------------------------------------------------------------------------------------------------------------------------------
int tc66c_send_cmd(TC66C_Device *tc66c_device, const char *message) {
    /*  Helper function for sending commands to the TC66C device.  Refer to the script header comment for valid commands 
        that can be sent to the TC66C device. */

    // Ensure that the TC66C device instance has been initialised properly
    if (tc66c_device == NULL || tc66c_device->serial_port == NULL) {
        fprintf(stderr, "[ERROR] - The TC66C device instance has not been initialised properly\n");
        return -1;
    }

    // Ensure that the message is not empty
    if (message[0] == '\0') {
        fprintf(stderr, "[ERROR] - The command message is empty\n");
        return -1;
    }

    // Write the message to the TC66C serial port
    int status = sp_blocking_write(tc66c_device->serial_port, message, strlen(message), 1000);

    // Check if the write was successful
    if (status < 0) {
        fprintf(stderr, "[ERROR] - Failed to write message to port: %s\n", sp_last_error_message());
        return -1;
    }

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
static int reorder_packet_blocks(uint8_t *decrypted_buffer) {
    /* Internal helper function for reordering the decrypted buffer based on block tags. If the tc66c_poll function detects
       an incorrectly ordered packet, it will call this function to reorder the blocks before processing. */

    // Define the expected block tags for each chunk for validation
    const char expected_tag_1[] = "pac1";
    const char expected_tag_2[] = "pac2";
    const char expected_tag_3[] = "pac3";

    // Define normalised buffer as intermediary holding for data getting sorted
    uint8_t fix_holding_buffer[192];
    memset(fix_holding_buffer, 0, sizeof(fix_holding_buffer));

    // Define flags to track which blocks have been seen
    int seen_pac1 = 0;
    int seen_pac2 = 0;
    int seen_pac3 = 0;

    // Loop through each 64-byte block, check tag, then copy that block into the correct position in the holding buffer
    for (int i = 0; i < 3; i++) {

        // Define the block pointer for the current block and var for holding pac tag
        uint8_t *block_pointer = decrypted_buffer + (i * 64);
        char block_tag[4] = { block_pointer[0], block_pointer[1], block_pointer[2], block_pointer[3] };

        // Determine which block tag is present and copy the block to the correct position in the holding buffer
        if (memcmp(block_tag, expected_tag_1, 4) == 0) {

            // Check if pac1 has already been seen
            if (seen_pac1) {
                fprintf(stderr, "[ERROR] - Duplicate pac1 block detected in TC66C packet.\n");
                return -1;
            }

            // Copy the block to the correct position in the holding buffer and mark pac1 as seen
            memcpy(fix_holding_buffer + 0, block_pointer, 64);
            seen_pac1 = 1;

        }
        else if (memcmp(block_tag, expected_tag_2, 4) == 0) {

            // Check if pac2 has already been seen
            if (seen_pac2) {
                fprintf(stderr, "[ERROR] - Duplicate pac2 block detected in TC66C packet.\n");
                return -1;
            }

            // Copy the block to the correct position in the holding buffer and mark pac2 as seen
            memcpy(fix_holding_buffer + 64, block_pointer, 64);
            seen_pac2 = 1;

        }
        else if (memcmp(block_tag, expected_tag_3, 4) == 0) {

            // Check if pac3 has already been seen
            if (seen_pac3) {
                fprintf(stderr, "[ERROR] - Duplicate pac3 block detected in TC66C packet.\n");
                return -1;
            }

            // Copy the block to the correct position in the holding buffer and mark pac3 as seen
            memcpy(fix_holding_buffer + 128, block_pointer, 64);
            seen_pac3 = 1;

        } 
        else {
            fprintf(stderr, "[ERROR] - Unrecognised block tag: %.4s\n", block_tag);
            return -1;

        }
    
    }

    // Ensure that all required blocks have been seen before proceeding
    if (!seen_pac1 || !seen_pac2 || !seen_pac3) {
        fprintf(stderr, "[ERROR] - Missing required packet block during TC66C packet normalization.\n");
        return -1;
    }

    // Copy the fixed holding buffer back to the decrypted buffer for further processing
    memcpy(decrypted_buffer, fix_holding_buffer, 192);

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int tc66c_poll(TC66C_Device *tc66c_device, TC66C_PollData *poll_data) {
    /*  Function for polling the TC66C device for data. It retrieves the current voltage, current, power, and temperature 
        readings and stores them in the provided poll_data structure. */

    // Ensure that the TC66C device instance has been initialised properly before proceeding
    if (tc66c_device == NULL || tc66c_device->serial_port == NULL || poll_data == NULL) {
        fprintf(stderr, "[ERROR] - The TC66C device instance has not been initialised properly\n");
        return -1;
    }

    // Set the command to send and declare response buffers
    const char command[] = "getva";
    uint8_t encrypted_buffer[192];
    uint8_t decrypted_buffer[192];

    // Send the getva command to the TC66C meter 
    int write_status = sp_blocking_write(tc66c_device->serial_port, command, strlen(command), 1000);

    // Check if the complete command was written successfully
    if (write_status < 0 || (size_t)write_status != strlen(command)) {
        fprintf(stderr, "[ERROR] - Failed to send full getva command to TC66C device.\n");
        return -1;
    }

    // Read in the encrypted response from the TC66C meter     
    int read_status = sp_blocking_read(tc66c_device->serial_port, encrypted_buffer, sizeof(encrypted_buffer), 1000);

    // Ensure that the read operation was successful and that the expected number of bytes were received
    if (read_status < 0 || read_status != (int)sizeof(encrypted_buffer)) {
        fprintf(stderr, "[ERROR] - Malformed TC66C packet (expected %zu bytes, got %d).\n", sizeof(encrypted_buffer), read_status);
        return -1;
    }

    // Decrypt the received packet using EVP
    int decrypted_len = 0;
    int final_len = 0;

    // Ensure that the AES decryption context is valid before proceeding
    if (EVP_DecryptInit_ex(tc66c_device->aes_ctx, NULL, NULL, NULL, NULL) != 1) {
        fprintf(stderr, "Error: Failed to reset AES decryption context\n");
        return -1;
    }

    // Decrypt the packet and check for errors
    if (EVP_DecryptUpdate(tc66c_device->aes_ctx, decrypted_buffer, &decrypted_len, encrypted_buffer, sizeof(encrypted_buffer)) != 1) {
        fprintf(stderr, "Error: Failed to decrypt TC66C packet\n");
        return -1;
    }

    // Finalize the decryption and check for errors
    if (EVP_DecryptFinal_ex(tc66c_device->aes_ctx, decrypted_buffer + decrypted_len, &final_len) != 1) {
        fprintf(stderr, "Error: Failed to finalize TC66C packet decryption\n");
        return -1;
    }

    // Determine if the decrypted packet chunks are in the correct order before proceeding, if not, attempt to sort them into the correct order
    if (memcmp(decrypted_buffer + 0, "pac1", 4) != 0 || memcmp(decrypted_buffer + 64, "pac2", 4) != 0 || memcmp(decrypted_buffer + 128, "pac3", 4) != 0) {
                
        // Attempt to reorder the blocks into the correct order
        if (reorder_packet_blocks(decrypted_buffer) != 0) {
            fprintf(stderr, "[ERROR] - Failed to reorder TC66C packet blocks into the correct order.\n");
            return -1;
        }

    }

    // Extract the device details from the decrypted buffer
    memcpy(poll_data->name, decrypted_buffer + 4, 4);
    poll_data->name[4] = '\0';
    memcpy(poll_data->Version, decrypted_buffer + 8, 4);
    poll_data->Version[4] = '\0';
    uint32_t sn_raw = *(uint32_t *)(decrypted_buffer + 12);
    snprintf(poll_data->serial_num, sizeof(poll_data->serial_num), "%u", sn_raw);

    // Extract the energy metrics from the decrypted buffer
    poll_data->sample_runs = *(uint32_t *)(decrypted_buffer + 44);
    poll_data->voltage = *(uint32_t *)(decrypted_buffer + 48) * 1e-4;
    poll_data->current = *(uint32_t *)(decrypted_buffer + 52) * 1e-5;
    poll_data->power = *(uint32_t *)(decrypted_buffer + 56) * 1e-4;
    poll_data->resistance = *(uint32_t *)(decrypted_buffer + 68) * 1e-1;
    poll_data->G0_mAh = *(uint32_t *)(decrypted_buffer + 72);
    poll_data->G0_mWh = *(uint32_t *)(decrypted_buffer + 76);
    poll_data->G1_mAh = *(uint32_t *)(decrypted_buffer + 80);
    poll_data->G1_mWh = *(uint32_t *)(decrypted_buffer + 84);
    poll_data->temp = *(int32_t *)(decrypted_buffer + 92);
    poll_data->D_plus = *(uint32_t *)(decrypted_buffer + 96) * 1e-2;
    poll_data->D_minus = *(uint32_t *)(decrypted_buffer + 100) * 1e-2;

    return 0;

}

//-------------------------------------------------------------------------------------------------------------------------------
int tc66c_close(TC66C_Device *tc66c_device) {
    /*  Function for closing the TC66C device instance and releasing resources. It will close the serial port and free any
        associated resources. */

    // Ensure that the TC66C device instance has been initialised properly
    if (tc66c_device == NULL || tc66c_device->serial_port == NULL) {
        fprintf(stderr, "[ERROR] - The TC66C device instance has not been initialised properly\n");
        return -1;
    }

    // Close the serial port
    sp_close(tc66c_device->serial_port);
    sp_free_port(tc66c_device->serial_port);
    tc66c_device->serial_port = NULL;

    // Free the AES decryption context if it exists
    if (tc66c_device->aes_ctx != NULL) {
        EVP_CIPHER_CTX_free(tc66c_device->aes_ctx);
        tc66c_device->aes_ctx = NULL;
    }

    return 0;

}
