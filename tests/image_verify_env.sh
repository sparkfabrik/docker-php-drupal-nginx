#!/bin/bash

set -e
BASE_DIR=$(dirname "$(readlink -f "$0")")
#shellcheck disable=SC1091
source "${BASE_DIR}/lib/functions.sh"

function test_for_docker_logs_presence() {
  if ! docker logs "${CONTAINER_ID}" 2>&1 | grep -q "${CUR_TEST_VAL}"; then
    echo -e "Failed to find ${CUR_TEST_VAL} in docker logs of container: ${TEST_FAIL_STR}"
    docker logs "${CONTAINER_ID}"
    exit 9
  else
    echo -e "Found ${CUR_TEST_VAL} in docker logs of container: ${TEST_PASSED_STR}"
  fi
}

function test_for_regexp_presence_in_file() {
  if ! docker exec "${CONTAINER_ID}" grep -q "${REGEX_TO_FIND}" "${FILE_TO_SEARCH}"; then
    echo -e "Failed to find regex ${REGEX_TO_FIND} in file: ${FILE_TO_SEARCH}: ${TEST_FAIL_STR}"
    exit 9
  else
    echo -e "Found ${REGEX_TO_FIND} in file: ${FILE_TO_SEARCH}: ${TEST_PASSED_STR}"
  fi
}

function verify_expectations_docker_logs() {
  if [ -f "${SOURCE_FILE}" ]; then
    TEST_FAIL_STR="\e[31mFAIL\e[39m"
    TEST_PASSED_STR="\e[32mOK\e[39m"
    while read -r line || [ -n "$line" ]; do
      if [ "${line}" = "$(echo -e "${line}" | tr -d '#')" ]; then
        CUR_TEST_VAR=$(echo -e "${line}" | awk -F'=' '{print $1}')
        CUR_TEST_VAL=$(echo -e "${line}" | awk -F'=' '{for (i=2; i<NF; i++) printf $i "="; print $NF;}' | sed 's/"//g')
        if [ "${CUR_TEST_VAR}" = "IN_LOGS" ]; then
          test_for_docker_logs_presence
        elif [ "${CUR_TEST_VAR}" = "FILE_TO_SEARCH" ]; then
          FILE_TO_SEARCH="${CUR_TEST_VAL}"
        elif [ "${CUR_TEST_VAR}" = "REGEX_TO_FIND" ]; then
          REGEX_TO_FIND="${CUR_TEST_VAL}"
          test_for_regexp_presence_in_file
          FILE_TO_SEARCH=""
          REGEX_TO_FIND=""
        fi
      fi
    done <"${SOURCE_FILE}"
  fi
}

set_initial_vars
parse_args "$@"
validate_docker_image_presence
process_docker_env
get_container_id
verify_expectations_docker_logs
stop_containers
