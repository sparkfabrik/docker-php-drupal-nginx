#!/bin/bash
# shellcheck disable=SC3037

### Exit status ###
# 0:    success
# 1:    unsupported flag
# 2:    the specified source file (expectations) is not found
# 3:    the specified env file is not found
# 4:    the docker image to test is not given as argument
# 5:    the test function is called without any test variables
# 6:    some tests fails
# 7:    failed to find the docker image
# 8:    failed to find the docker test image
# 9:    docker run fails
# 10:   failed to discover the IP address of the docker image
# 11:   Failed to get the data
#####################

BASE_DIR=$(dirname "$(readlink -f "$0")")
#shellcheck disable=SC1091
source "${BASE_DIR}/lib/functions.sh"

EXIT_STATUS=0
set_initial_vars
parse_args "$@"
validate_docker_image_presence
handle_php_is_needed
process_docker_env
get_container_id
get_container_ip
get_http_test_output
parse_http_test_output
validate_source_file_http_expectations
test_for_user
stop_containers

debug "HEADER REQ"
debug "${DOCKER_TEST_HEADER_REQ}"
debug "BODY REQ"
debug "${DOCKER_TEST_BODY_REQ}"
debug "HEADER RES"
debug "${DOCKER_TEST_HEADER_RES}"
debug "BODY RES"
debug "${DOCKER_TEST_BODY_RES}"

exit $EXIT_STATUS
