#!/bin/bash

# Copyright (c) 2023-2026 Callum Turino
# SPDX-License-Identifier: MIT

# This utility script manages custom OID environment variable mappings used only during TLS operations energy testing in
# the PQC-LEO benchmarking suite. It is an internal helper invoked by the TLS operations energy test workflow and is not
# intended to be called manually. It supports setting or clearing OID mappings so OpenSSL and OQS-Provider can
# reference consistent private enterprise OIDs during controlled interoperability and performance test runs.
#
# The script accepts one command line argument which is used to indicate whether the OID environment variables 
# should be set or cleared. This flag is mandatory for the script to function correctly. 
# The supported options are:
# `--set-env-oids` to set the OID environment variables for all supported algorithms
# `--clear-env-oids` to clear those environment variables after testing is complete. 
#
# The algorithms that are included within this script are based on the algorithms listed by OQS-Provider
# in their ALGORITHMS.md file (OQS-Provider version 0.11.0+). Currently, the script is hard-coded to include 
# the algorithms mentioned in that file. This will be updated in the future to be more dynamic.
# The version of the ALGORITHMS.md file used to dictate the algorithms included in this script can be found here:
# https://github.com/open-quantum-safe/oqs-provider/blob/1670a8a91bbca997d33e6b6851309d6241cc224c/ALGORITHMS.md

#-------------------------------------------------------------------------------------------------------------------------------
function get_root_dir() {
    # Function for determining the root directory of the PQC-LEO repository. The function will keep going up the directory tree
    # until it finds the .pqc_leo_dir_marker.tmp file, which is used to indicate the root directory of the repository. Once
    # found it will set the root_dir variable to the path of the root directory.

    # Determine the directory that the script is being run from
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

    # Try and find the .dir_marker.tmp file to determine the project's root directory
    current_dir="$script_dir"

    # Continue moving up the directory tree until the .pqc_leo_dir_marker.tmp file is found
    while true; do

        # Check if the .pqc_leo_dir_marker.tmp file is present
        if [ -f "$current_dir/.pqc_leo_dir_marker.tmp" ]; then
            root_dir="$current_dir"
            break
        fi

        # Move up a directory and store the new path
        current_dir=$(dirname "$current_dir")

        # If the system's root directory is reached and the file is not found, exit the script
        if [ "$current_dir" == "/" ]; then
            echo -e "Root directory path file not present, please ensure the path is correct and try again."
            exit 1
        fi

    done

}

#-------------------------------------------------------------------------------------------------------------------------------
function output_help() {
    # Helper function for outputting the help message to the user when the --help flag is present or when incorrect arguments 
    # are passed.

    # Output the help message for the oqs_enable_algs modification tool
    echo "Usage: oid_handler.sh [options]"
    echo "Options:"
    echo "--set-env-oids        Set OID environment variables for quantum-safe algorithms"
    echo "--clear-env-oids      Clear OID environment variables for quantum-safe algorithms"
    echo "--help                Display the help message"

}

#-------------------------------------------------------------------------------------------------------------------------------
function parse_args() {
    # Function for parsing the command line arguments passed to the script. Based on the detected arguments, the function will 
    # set the relevant global flags that are used throughout the setup process.

    # Check if the help flag is passed at any position in the command line arguments
    if [[ "$*" =~ --help ]]; then
        output_help
        exit 0
    fi

    # Set the default option selected flag
    configure_mode=0
    local set_flag_seen=0
    local clear_flag_seen=0

    # Loop through the passed command line arguments and check for the supported options
    while [[ $# -gt 0 ]]; do

        case "$1" in

            --set-env-oids)

                # Check if either flag has already been seen, as only one of the two options can be passed
                if [[ $set_flag_seen -eq 1 || $clear_flag_seen -eq 1 ]]; then
                    echo "[ERROR] - Only one of --set-env-oids or --clear-env-oids can be passed."
                    output_help
                    exit 1
                fi

                # Set the flag for setting OID environment variables and update the configure mode
                set_flag_seen=1
                configure_mode=1
                shift
                ;;

            --clear-env-oids)

                # Check if either flag has already been seen, as only one of the two options can be passed
                if [[ $clear_flag_seen -eq 1 || $set_flag_seen -eq 1 ]]; then
                    echo "[ERROR] - Only one of --set-env-oids or --clear-env-oids can be passed."
                    output_help
                    exit 1
                fi

                # Set the flag for clearing OID environment variables and update the configure mode
                clear_flag_seen=1
                configure_mode=2
                shift
                ;;

            *)

                # Output an error message for invalid options and display the help message
                echo "[ERROR] - Invalid option: $1"
                output_help
                exit 1
                ;;

        esac

    done

    # Ensure that at least one of the required options has been provided to the script
    if [[ $configure_mode -eq 0 ]]; then
        echo "[ERROR] - One option is required: --set-env-oids or --clear-env-oids"
        output_help
        exit 1
    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function define_oid_var_arrays() {
    # Function for defining the arrays of OID variables that are used throughout the script. This includes the list of OIDs
    # that are excluded from being exported as environment variables, the list of OIDs that require an enabled check, and
    # the list of all OID variables that are used for setting and clearing the environment variables. Changes can be made
    # to these arrays to add or remove algorithms from the OID handling process, but care should be taken to ensure that the
    # algorithms are supported by OQS-Provider and that the OID variables are correctly defined in the script. Please
    # refer to the script header comment for more information on the algorithms included in this script.

    # Define algorithm OIDs to exclude from being exported as environment variables
    exlcuded_algs=(
        "OQS_OID_MLDSA44"
        "OQS_OID_MLDSA65"
        "OQS_OID_MLDSA87"
        "OQS_OID_X25519MLKEM768"
        "OQS_OID_SECP256R1MLKEM768"
        "OQS_OID_SECP384R1MLKEM1024"
        "OQS_OID_X448MLKEM1024"
    )

    # Define OID variables for algorithms which are disabled by default in OQS-Provider
    algs_need_enabled_check=(

        # CROSS signature algorithms that need enabled check
        "OQS_OID_CROSSRSDP128FAST"
        "OQS_OID_CROSSRSDP128SMALL"
        "OQS_OID_CROSSRSDP192BALANCED"
        "OQS_OID_CROSSRSDP192FAST"
        "OQS_OID_CROSSRSDP192SMALL"
        "OQS_OID_CROSSRSDP256SMALL"
        "OQS_OID_CROSSRSDPG128BALANCED"
        "OQS_OID_CROSSRSDPG128FAST"
        "OQS_OID_CROSSRSDPG128SMALL"
        "OQS_OID_CROSSRSDPG192BALANCED"
        "OQS_OID_CROSSRSDPG192FAST"
        "OQS_OID_CROSSRSDPG192SMALL"
        "OQS_OID_CROSSRSDPG256BALANCED"
        "OQS_OID_CROSSRSDPG256FAST"
        "OQS_OID_CROSSRSDPG256SMALL"

        # OV signature algorithms that need enabled check
        "OQS_OID_OV_IS"
        "OQS_OID_P256_OV_IS"
        "OQS_OID_OV_IP"
        "OQS_OID_P256_OV_IP"
        "OQS_OID_OV_III"
        "OQS_OID_P384_OV_III"
        "OQS_OID_OV_V"
        "OQS_OID_P521_OV_V"
        "OQS_OID_OV_IS_PKC"
        "OQS_OID_P256_OV_IS_PKC"
        "OQS_OID_OV_III_PKC"
        "OQS_OID_P384_OV_III_PKC"
        "OQS_OID_OV_V_PKC"
        "OQS_OID_P521_OV_V_PKC"
        "OQS_OID_OV_IS_PKC_SKC"
        "OQS_OID_P256_OV_IS_PKC_SKC"
        "OQS_OID_OV_III_PKC_SKC"
        "OQS_OID_P384_OV_III_PKC_SKC"
        "OQS_OID_OV_V_PKC_SKC"
        "OQS_OID_P521_OV_V_PKC_SKC"

        # SNOVA signature algorithms that need enabled check
        "OQS_OID_SNOVA2454SHAKE"
        "OQS_OID_P256_SNOVA2454SHAKE"
        "OQS_OID_SNOVA2454SHAKEESK"
        "OQS_OID_P256_SNOVA2454SHAKEESK"
        "OQS_OID_SNOVA2583"
        "OQS_OID_P256_SNOVA2583"
        "OQS_OID_SNOVA56252"
        "OQS_OID_P384_SNOVA56252"
        "OQS_OID_SNOVA49113"
        "OQS_OID_P384_SNOVA49113"
        "OQS_OID_SNOVA3784"
        "OQS_OID_P384_SNOVA3784"
        "OQS_OID_SNOVA60104"
        "OQS_OID_P521_SNOVA60104"

        # MQOM signature algorithms that need enabled check
        "OQS_OID_MQOM2CAT1GF16FASTR3"
        "OQS_OID_P256_MQOM2CAT1GF16FASTR3"
        "OQS_OID_MQOM2CAT1GF16SHORTR5"
        "OQS_OID_P256_MQOM2CAT1GF16SHORTR5"
        "OQS_OID_MQOM2CAT1GF16SHORTR3"
        "OQS_OID_P256_MQOM2CAT1GF16SHORTR3"
        "OQS_OID_MQOM2CAT3GF16FASTR3"
        "OQS_OID_P384_MQOM2CAT3GF16FASTR3"
        "OQS_OID_MQOM2CAT3GF16SHORTR5"
        "OQS_OID_P384_MQOM2CAT3GF16SHORTR5"
        "OQS_OID_MQOM2CAT3GF16SHORTR3"
        "OQS_OID_P384_MQOM2CAT3GF16SHORTR3"
        "OQS_OID_MQOM2CAT5GF16FASTR3"
        "OQS_OID_P521_MQOM2CAT5GF16FASTR3"
        "OQS_OID_MQOM2CAT5GF16SHORTR5"
        "OQS_OID_P521_MQOM2CAT5GF16SHORTR5"
        "OQS_OID_MQOM2CAT5GF16SHORTR3"
        "OQS_OID_P521_MQOM2CAT5GF16SHORTR3"

        # BIKE KEM algorithms that need enabled check
        "OQS_OID_BIKEL1"
        "OQS_OID_P256_BIKEL1"
        "OQS_OID_X25519_BIKEL1"

    )

    # Define all OID variables names
    alg_oid_vars=(

        # ML-DSA signature OID vars
        "OQS_OID_MLDSA44"
        "OQS_OID_P256_MLDSA44"
        "OQS_OID_RSA3072_MLDSA44"
        "OQS_OID_MLDSA65"
        "OQS_OID_P384_MLDSA65"
        "OQS_OID_MLDSA87"
        "OQS_OID_P521_MLDSA87"

        # Falcon signature OID vars
        "OQS_OID_FALCON512"
        "OQS_OID_P256_FALCON512"
        "OQS_OID_RSA3072_FALCON512"
        "OQS_OID_FALCONPADDED512"
        "OQS_OID_P256_FALCONPADDED512"
        "OQS_OID_RSA3072_FALCONPADDED512"
        "OQS_OID_FALCON1024"
        "OQS_OID_P521_FALCON1024"
        "OQS_OID_FALCONPADDED1024"
        "OQS_OID_P521_FALCONPADDED1024"

        # MAYO signature OID vars
        "OQS_OID_MAYO1"
        "OQS_OID_P256_MAYO1"
        "OQS_OID_MAYO2"
        "OQS_OID_P256_MAYO2"
        "OQS_OID_MAYO3"
        "OQS_OID_P384_MAYO3"
        "OQS_OID_MAYO5"
        "OQS_OID_P521_MAYO5"

        # CROSS signature OID vars
        "OQS_OID_CROSSRSDP128BALANCED"
        "OQS_OID_CROSSRSDP128FAST"
        "OQS_OID_CROSSRSDP128SMALL"
        "OQS_OID_CROSSRSDP192BALANCED"
        "OQS_OID_CROSSRSDP192FAST"
        "OQS_OID_CROSSRSDP192SMALL"
        "OQS_OID_CROSSRSDP256SMALL"
        "OQS_OID_CROSSRSDPG128BALANCED"
        "OQS_OID_CROSSRSDPG128FAST"
        "OQS_OID_CROSSRSDPG128SMALL"
        "OQS_OID_CROSSRSDPG192BALANCED"
        "OQS_OID_CROSSRSDPG192FAST"
        "OQS_OID_CROSSRSDPG192SMALL"
        "OQS_OID_CROSSRSDPG256BALANCED"
        "OQS_OID_CROSSRSDPG256FAST"
        "OQS_OID_CROSSRSDPG256SMALL"

        # OV signature OID vars
        "OQS_OID_OV_IS"
        "OQS_OID_P256_OV_IS"
        "OQS_OID_OV_IP"
        "OQS_OID_P256_OV_IP"
        "OQS_OID_OV_III"
        "OQS_OID_P384_OV_III"
        "OQS_OID_OV_V"
        "OQS_OID_P521_OV_V"
        "OQS_OID_OV_IS_PKC"
        "OQS_OID_P256_OV_IS_PKC"
        "OQS_OID_OV_IP_PKC"
        "OQS_OID_P256_OV_IP_PKC"
        "OQS_OID_OV_III_PKC"
        "OQS_OID_P384_OV_III_PKC"
        "OQS_OID_OV_V_PKC"
        "OQS_OID_P521_OV_V_PKC"
        "OQS_OID_OV_IS_PKC_SKC"
        "OQS_OID_P256_OV_IS_PKC_SKC"
        "OQS_OID_OV_IP_PKC_SKC"
        "OQS_OID_P256_OV_IP_PKC_SKC"
        "OQS_OID_OV_III_PKC_SKC"
        "OQS_OID_P384_OV_III_PKC_SKC"
        "OQS_OID_OV_V_PKC_SKC"
        "OQS_OID_P521_OV_V_PKC_SKC"

        # SNOVA signature OID vars
        "OQS_OID_SNOVA2454"
        "OQS_OID_P256_SNOVA2454"
        "OQS_OID_SNOVA2454SHAKE"
        "OQS_OID_P256_SNOVA2454SHAKE"
        "OQS_OID_SNOVA2454ESK"
        "OQS_OID_P256_SNOVA2454ESK"
        "OQS_OID_SNOVA2454SHAKEESK"
        "OQS_OID_P256_SNOVA2454SHAKEESK"
        "OQS_OID_SNOVA37172"
        "OQS_OID_P256_SNOVA37172"
        "OQS_OID_SNOVA2583"
        "OQS_OID_P256_SNOVA2583"
        "OQS_OID_SNOVA56252"
        "OQS_OID_P384_SNOVA56252"
        "OQS_OID_SNOVA49113"
        "OQS_OID_P384_SNOVA49113"
        "OQS_OID_SNOVA3784"
        "OQS_OID_P384_SNOVA3784"
        "OQS_OID_SNOVA2455"
        "OQS_OID_P384_SNOVA2455"
        "OQS_OID_SNOVA60104"
        "OQS_OID_P521_SNOVA60104"
        "OQS_OID_SNOVA2965"
        "OQS_OID_P521_SNOVA2965"

        # MQOM signature OID vars
        "OQS_OID_MQOM2CAT1GF16FASTR5"
        "OQS_OID_P256_MQOM2CAT1GF16FASTR5"
        "OQS_OID_MQOM2CAT1GF16FASTR3"
        "OQS_OID_P256_MQOM2CAT1GF16FASTR3"
        "OQS_OID_MQOM2CAT1GF16SHORTR5"
        "OQS_OID_P256_MQOM2CAT1GF16SHORTR5"
        "OQS_OID_MQOM2CAT1GF16SHORTR3"
        "OQS_OID_P256_MQOM2CAT1GF16SHORTR3"
        "OQS_OID_MQOM2CAT3GF16FASTR5"
        "OQS_OID_P384_MQOM2CAT3GF16FASTR5"
        "OQS_OID_MQOM2CAT3GF16FASTR3"
        "OQS_OID_P384_MQOM2CAT3GF16FASTR3"
        "OQS_OID_MQOM2CAT3GF16SHORTR5"
        "OQS_OID_P384_MQOM2CAT3GF16SHORTR5"
        "OQS_OID_MQOM2CAT3GF16SHORTR3"
        "OQS_OID_P384_MQOM2CAT3GF16SHORTR3"
        "OQS_OID_MQOM2CAT5GF16FASTR5"
        "OQS_OID_P521_MQOM2CAT5GF16FASTR5"
        "OQS_OID_MQOM2CAT5GF16FASTR3"
        "OQS_OID_P521_MQOM2CAT5GF16FASTR3"
        "OQS_OID_MQOM2CAT5GF16SHORTR5"
        "OQS_OID_P521_MQOM2CAT5GF16SHORTR5"
        "OQS_OID_MQOM2CAT5GF16SHORTR3"
        "OQS_OID_P521_MQOM2CAT5GF16SHORTR3"

        # eFrodo KEM OID vars
        "OQS_OID_EFRODO640AES"
        "OQS_OID_P256_EFRODO640AES"
        "OQS_OID_X25519_EFRODO640AES"
        "OQS_OID_EFRODO640SHAKE"
        "OQS_OID_P256_EFRODO640SHAKE"
        "OQS_OID_X25519_EFRODO640SHAKE"
        "OQS_OID_EFRODO976AES"
        "OQS_OID_P384_EFRODO976AES"
        "OQS_OID_X448_EFRODO976AES"
        "OQS_OID_EFRODO976SHAKE"
        "OQS_OID_P384_EFRODO976SHAKE"
        "OQS_OID_X448_EFRODO976SHAKE"
        "OQS_OID_EFRODO1344AES"
        "OQS_OID_P521_EFRODO1344AES"
        "OQS_OID_EFRODO1344SHAKE"
        "OQS_OID_P521_EFRODO1344SHAKE"

        # Frodo KEM OID vars
        "OQS_OID_FRODO640AES"
        "OQS_OID_P256_FRODO640AES"
        "OQS_OID_X25519_FRODO640AES"
        "OQS_OID_FRODO640SHAKE"
        "OQS_OID_P256_FRODO640SHAKE"
        "OQS_OID_X25519_FRODO640SHAKE"
        "OQS_OID_FRODO976AES"
        "OQS_OID_P384_FRODO976AES"
        "OQS_OID_X448_FRODO976AES"
        "OQS_OID_FRODO976SHAKE"
        "OQS_OID_P384_FRODO976SHAKE"
        "OQS_OID_X448_FRODO976SHAKE"
        "OQS_OID_FRODO1344AES"
        "OQS_OID_P521_FRODO1344AES"
        "OQS_OID_FRODO1344SHAKE"
        "OQS_OID_P521_FRODO1344SHAKE"

        # ML-KEM KEM OID vars
        "OQS_OID_MLKEM512"
        "OQS_OID_P256_MLKEM512"
        "OQS_OID_X25519_MLKEM512"
        "OQS_OID_BP256_MLKEM512"
        "OQS_OID_MLKEM768"
        "OQS_OID_P384_MLKEM768"
        "OQS_OID_X448_MLKEM768"
        "OQS_OID_BP384_MLKEM768"
        "OQS_OID_X25519MLKEM768"
        "OQS_OID_SECP256R1MLKEM768"
        "OQS_OID_MLKEM1024"
        "OQS_OID_P521_MLKEM1024"
        "OQS_OID_SECP384R1MLKEM1024"
        "OQS_OID_BP512_MLKEM1024"
        "OQS_OID_X448MLKEM1024"

        # BIKE KEM OID vars
        "OQS_OID_BIKEL1"
        "OQS_OID_P256_BIKEL1"
        "OQS_OID_X25519_BIKEL1"
        "OQS_OID_BIKEL3"
        "OQS_OID_P384_BIKEL3"
        "OQS_OID_X448_BIKEL3"
        "OQS_OID_BIKEL5"
        "OQS_OID_P521_BIKEL5"

        # HQC KEM OID vars
        "OQS_OID_HQC1"
        "OQS_OID_P256_HQC1"
        "OQS_OID_X25519_HQC1"
        "OQS_OID_HQC3"
        "OQS_OID_P384_HQC3"
        "OQS_OID_X448_HQC3"
        "OQS_OID_HQC5"
        "OQS_OID_P521_HQC5"
    )

}

#-------------------------------------------------------------------------------------------------------------------------------
function actionable_algorithm_check() {
    # Helper function for determing if the passed algorithm OID variables is one that shoudl either be set or unset based on
    # whether it is in the excluded list or requires an enabled check. If the algorithm is actionable, the function will return
    # 0, otherwise it will return 1.

    # Store the passed algorithm OID variable name
    local alg_oid_var=$1

    # Check if the algorithm OID variable is in the excluded list
    if [[ " ${exlcuded_algs[@]} " =~ " ${alg_oid_var} " ]]; then
        return 1
    fi

    # Check if the algorithm OID variable requires an enabled check and if the flag file is present
    if [[ " ${algs_need_enabled_check[@]} " =~ " ${alg_oid_var} " ]] && [ ! -f "$tmp_dir/.oqs_prov_algs_enabled.flag" ]; then
        return 1
    fi

    # If the algorithm OID variable is not in the excluded list and does not require an enabled check, it is actionable
    return 0

}

#-------------------------------------------------------------------------------------------------------------------------------
function OID_handler() {
    # Function to manage OID (Object Identifier) environment variables for TLS operations energy testing. Due to the algorithms
    # present in OQS-Provider not being fully standardised, custom OID's must be assigned to the algorithms included within 
    # OQS-Provider in order to use them within manual cryptographic operations in OpenSSL. To do this, algorithms are provided 
    # with a base OID from a private enterprise OID space (1.3.6.1.4.1.555555.9000) and then assigned an OID variable in the 
    # environment. Based on the argument passed to the script, this function will either set or clear these environment variables.

    # Store the passed configure mode and define the base OID prefix for the custom OIDs
    local set_type=$1
    local base_oid=1.3.6.1.4.1.555555.9000
    local oid_offset_value=1

    # Define the OID variable arrays for performing export/unset operations
    define_oid_var_arrays


    # Determine which set action to perform based on the passed configure mode
    if [ "$set_type" -eq 1 ]; then

        # Loop through each of the defined OID variables
        for oid_var in "${alg_oid_vars[@]}"; do

            # Define the full OID value that will be assigned to the OID variable in the environment
            new_oid_value="${base_oid}.${oid_offset_value}"

            # Perform algorithm checks to determine if the OID variable is one that an action should be taken
            if actionable_algorithm_check "$oid_var"; then
                export "$oid_var=$new_oid_value"
            fi

            # Increase the OID offset value for the next OID variable to ensure unique OIDs are assigned
            ((oid_offset_value++))

        done

    elif [ "$set_type" -eq 2 ]; then

        # Loop through each of the defined OID variables
        for oid_var in "${alg_oid_vars[@]}"; do

            # Perform algorithm checks to determine if the OID variable is one that an action should be taken
            if actionable_algorithm_check "$oid_var"; then
                unset "$oid_var"
            fi

        done

    fi

}

#-------------------------------------------------------------------------------------------------------------------------------
function oid_handler_entrypoint() {
    # Main entry point for the OID handler script. This function is responsible for orchestrating the execution of the script 
    # by first parsing the command line arguments and then calling the OID handler function with the relevant configuration 
    # mode based on the detected arguments.

    # Ensure that arugments have been passed to the script
    if [[ $# -gt 0 ]]; then

        # Determine the project root directory path
        root_dir=""
        get_root_dir

        # Ensure that the temporary directory exists before proceeding
        tmp_dir="$root_dir/tmp"
        if [ ! -d "$tmp_dir" ]; then
            echo "[ERROR] - Temporary directory not found at $tmp_dir. Please ensure the setup.sh script has been run and try again."
            exit 1
        fi

        # Parse the command line arguments and call the OID handler function with the relevant configuration mode
        parse_args "$@"
        OID_handler $configure_mode

    else

        # Output an error message if no arguments are provided and display the help message
        echo "[ERROR] - No arguments provided. One of --set-env-oids or --clear-env-oids is required."
        output_help
        exit 1

    fi

}
oid_handler_entrypoint "$@"