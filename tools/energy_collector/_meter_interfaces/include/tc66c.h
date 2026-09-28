/*
Copyright (c) 2023-2026 Callum Turino
SPDX-License-Identifier: MIT
*/

#ifndef TC66C_H
#define TC66C_H

#include <stdint.h>
#include <stddef.h>
#include <libserialport.h>
#include <openssl/evp.h>

// Define constants for TC66C communication and data parsing
#define TC66C_PACKET_SIZE 192   // AES-encrypted payload size
#define TC66C_MAX_RECORDS 1440  // Max historical samples
#define TC66C_NAME_LEN    5     // 4 chars + null terminator
#define DEFAULT_COM_PORT ""

/**
 * Stores the current reading values from the TC66C meter.
 *
 * @param name Device name/model string.
 * @param Version Device firmware/version string.
 * @param serial_num Device serial number string.
 * @param sample_runs Number of sample runs reported by the device.
 * @param voltage Current voltage reading.
 * @param current Current current reading.
 * @param power Current power reading.
 * @param resistance Current resistance reading.
 * @param G0_maH Reserved legacy field.
 * @param G0_mAh Group 0 accumulated mAh.
 * @param G0_mWh Group 0 accumulated mWh.
 * @param G1_mAh Group 1 accumulated mAh.
 * @param G1_mWh Group 1 accumulated mWh.
 * @param temp Temperature value reported by the device.
 * @param D_plus D+ line metric.
 * @param D_minus D- line metric.
 */
typedef struct {
    char name[TC66C_NAME_LEN];
    char Version[TC66C_NAME_LEN];
    char serial_num[12];
    uint32_t sample_runs;
    float voltage;
    float current;
    float power;
    float resistance;
    uint32_t G0_maH;
    uint32_t G0_mAh;
    uint32_t G0_mWh;
    uint32_t G1_mAh;
    uint32_t G1_mWh;
    int32_t temp;
    float D_plus;
    float D_minus;
} TC66C_PollData;

// Static AES key for decrypting device messages
static const uint8_t TC66C_STATIC_KEY[32] = {
    0x58, 0x21, 0xFA, 0x56,
    0x01, 0xB2, 0xF0, 0x26,
    0x87, 0xFF, 0x12, 0x04, 
    0x62, 0x2A, 0x4F, 0xB0,
    0x86, 0xF4, 0x02, 0x60,
    0x81, 0x6F, 0x9A, 0x0B,
    0xA7, 0xF1, 0x06, 0x61,
    0x9A, 0xB8, 0x72, 0x88,
};

/**
 * TC66C device instance which stores connection state and serial configuration.
 *
 * @param com_port Open libserialport device handle.
 * @param aes_ctx OpenSSL EVP decryption context used for poll_data packets.
 * @param baudrate Serial baud rate.
 * @param data_bits Serial data bits.
 * @param parity Serial parity mode.
 * @param stop_bits Serial stop bits.
 * @param flow_control Serial flow control mode.
 */
typedef struct {
    struct sp_port* com_port;
    EVP_CIPHER_CTX *aes_ctx;
    int baudrate;
    int data_bits;
    int parity;
    int stop_bits;
    int flow_control;
} TC66C_Device;

/**
 * Initialises the TC66C serial connection and AES decryption context.
 * The implementation configures fixed serial parameters and initialises 
 * AES-256-ECB with the static TC66C key.
 *
 * @param tc66c_device Pointer to the TC66C device instance.
 * @param com_port_name Serial port name used to open the device.
 * @return 0 on success, -1 on port open/configuration or AES context setup failure.
 */
int tc66c_init(TC66C_Device *tc66c_device, const char *com_port_name);

/**
 * Sends a raw command string to the TC66C serial interface.
 *
 * @param tc66c_device Pointer to the initialised TC66C device instance.
 * @param message Null-terminated command payload.
 * @return 0 on success, -1 if device/message is invalid or write fails.
 */
int tc66c_send_cmd(TC66C_Device *tc66c_device, const char *message);

/**
 * Polls the TC66C for live telemetry using the getva command.
 * Reads a fixed 192-byte encrypted packet, decrypts it with the current EVP
 * context, and maps decoded fields into TC66C_PollData.
 *
 * @param tc66c_device Pointer to the initialised TC66C device instance.
 * @param poll_data Output structure populated with decoded readings.
 * @return 0 on success, -1 on validation, decrypt reset, decrypt, or finalize failure.
 */
int tc66c_poll(TC66C_Device *tc66c_device, TC66C_PollData *poll_data);

/**
 * Closes the TC66C connection and releases associated resources.
 *
 * @param tc66c_device Pointer to the TC66C device instance.
 * @return 0 on success, -1 if the device instance is invalid.
 */
int tc66c_close(TC66C_Device *tc66c_device);

#endif