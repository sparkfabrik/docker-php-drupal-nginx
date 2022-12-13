#!/bin/sh
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

DEBUG="${DEBUG:-1}"
DRY_RUN=0

PHP_IS_NEEDED="${PHP_IS_NEEDED:-0}"
DOCKER_PHP_IMAGE="php:7.4-fpm"
DOCKER_PHP_IP=""

DOCKER_TEST_IMAGE="alpine/httpie:latest"
DOCKER_TEST_IP=""
DOCKER_TEST_PORT=80
DOCKER_TEST_PROTO="http"
DOCKER_TEST_PATH="${DOCKER_TEST_PATH:-test.html}"

DOCKER_TEST_OUTPUT=""
DOCKER_TEST_HEADER_REQ=""
DOCKER_TEST_HEADER_RES=""
DOCKER_TEST_BODY_REQ=""
DOCKER_TEST_BODY_RES=""

DOCKER_IMAGE=""
DOCKER_ENV=""
ENV_LIST=""
ENV_FILE=""

MOUNT_LIST=""

SOURCE_FILE=""

CUR_TEST_VAR=""
CUR_TEST_VAL=""

CORS_ORIGIN_HOST=""
REQ_HEADER_HOST=""

print_dry_run() {
  PAD=60
  cat <<EOM
You are running this script in dry-run mode.
I will test the defined expectations as defined below:

### Generic variables ###
EOM
printf "%-${PAD}s %s\n" "PHP_IS_NEEDED" "${PHP_IS_NEEDED}"
printf "%-${PAD}s %s\n" "DOCKER_TEST_IMAGE" "${DOCKER_TEST_IMAGE}"
printf "%-${PAD}s %s\n" "DOCKER_IMAGE" "${DOCKER_IMAGE}"
printf "%-${PAD}s %s\n" "PORT" "${DOCKER_TEST_PORT}"
printf "%-${PAD}s %s\n" "PROTO" "${DOCKER_TEST_PROTO}"
printf "%-${PAD}s %s\n" "PATH" "${DOCKER_TEST_PATH}"
printf "%-${PAD}s %s\n" "ENV_LIST" "${ENV_LIST}"
printf "%-${PAD}s %s\n" "ENV_FILE" "${ENV_FILE}"
printf "%-${PAD}s %s\n" "MOUNT_LIST" "${MOUNT_LIST}"
printf "%-${PAD}s %s\n" "SOURCE_FILE" "${SOURCE_FILE}"
printf "%-${PAD}s %s\n" "CORS_ORIGIN_HOST" "${CORS_ORIGIN_HOST}"
printf "%-${PAD}s %s\n" "REQ_HEADER_HOST" "${REQ_HEADER_HOST}"

if [ -n "${TEST_USER}" ]; then
    printf "%-${PAD}s %s\n" "CONTAINER_USER" "${TEST_USER}"
fi

cat <<EOM

### Defined variables ###
EOM
  while read -r line || [ -n "$line" ]; do
    if [ "${line}" = "$(echo -e "${line}" | tr -d '#')" ]; then
      CUR_TEST_VAR=$(echo -e "${line}" | awk -F'=' '{print $1}')
      CUR_TEST_VAL=$(echo -e "${line}" | awk -F'=' '{for (i=2; i<NF; i++) printf $i "="; print $NF;}' | sed 's/"//g')

      PRINT_VAR=""
      if [ "${CUR_TEST_VAR}" = "HTTP_STATUS" ]; then
        PRINT_VAR="HTTP Status Header"
      elif [ "${CUR_TEST_VAR}" = "BODY_RES" ]; then
        PRINT_VAR="Body response"
      elif [ "${CUR_TEST_VAR}" = "BODY_REQ" ]; then
        PRINT_VAR="Body request"
      elif [ "$(echo -e "${CUR_TEST_VAR}" | awk '$0 ~ /^HEADER_RES_/ {print 1}')" = "1" ]; then
        PRINT_VAR="Header response $(echo -e "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_RES_/,""); print $0}')"
      elif [ "$(echo -e "${CUR_TEST_VAR}" | awk '$0 ~ /^HEADER_REQ_/ {print 1}')" = "1" ]; then
        PRINT_VAR="Header request $(echo -e "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_REQ_/,""); print $0}')"
      fi

      if [ -n "${PRINT_VAR}" ]; then
        printf "%-${PAD}s %s\n" "${PRINT_VAR}" "${CUR_TEST_VAL}"
      fi
    fi
  done < "${SOURCE_FILE}"
}

show_usage() {
  cat <<EOM
Usage: $(basename "$0") [OPTIONS] [EXPECTATIONS] <DOCKER IMAGE> [DOCKER TEST IMAGE]
Options:
  --help,-h                           Print this help message
  --dry-run                           The script will only print the expectations
  --php-needed                        Enable PHP upstream
  --env,-e LIST                       Defines the comma separated environment variables to pass to the container
  --env-file PATH                     Defines a path for a file which includes all the ENV variables to pass to
                                      the container image (these variables will override the --env defined ones)
  -v STRING                           Defines the mount path for the container
  --http-port N                       Defines the HTTP port, if missing the default 80 port is used
  --http-proto STRING [http|https]    Defines the HTTP protocol to use, if missing the default http is used
  --http-path STRING                  Defines the HTTP path to use
  --source PATH                       Defines a path for a file which includes the desired expectations
  --cors-origin-host STRING           Defines the origin host used to test CORS
  --req-header-host STRING            Defines the host request header; not used if it is empty
  --user,-u STRING                    Defines the default user for the image
EOM
}

debug() {
  if [ -n "${1:-}" ] && [ "${DEBUG:-0}" -eq 1 ]; then
    echo -e "${1}"
  fi
}

process_docker_env() {
  if [ -n "${ENV_LIST}" ]; then
    DOCKER_ENV="-e $(echo "${ENV_LIST}" | sed 's/,/ -e /g;')"
  fi
  if [ -n "${ENV_FILE}" ]; then
    if [ -f "${ENV_FILE}" ]; then
      DOCKER_ENV="${DOCKER_ENV} --env-file ${ENV_FILE}"
    else
      echo -e "Failed to process the env configuration"
      exit 3
    fi
  fi
}

# Process arguments
PARAMS=""
while [ -n "${1}" ]; do
  case "$1" in
    --help|-h) show_usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --php-needed) PHP_IS_NEEDED="1"; shift 1 ;;
    --env|-e) if [ -n "${ENV_LIST}" ]; then ENV_LIST="${ENV_LIST},${2}"; else ENV_LIST="${2}"; fi; shift 2 ;;
    --env-file) ENV_FILE="${2}"; if [ ! -f "${ENV_FILE}" ]; then exit 3; fi; shift 2 ;;
    -v) if [ -n "${MOUNT_LIST}" ]; then MOUNT_LIST="${MOUNT_LIST} -v ${2}"; else MOUNT_LIST="-v ${2}"; fi; shift 2 ;;
    --http-port) DOCKER_TEST_PORT="${2}"; shift 2 ;;
    --http-proto) DOCKER_TEST_PROTO="${2}"; shift 2 ;;
    --http-path) DOCKER_TEST_PATH="${2}"; shift 2 ;;
    --source) SOURCE_FILE="${2}"; if [ ! -f "${SOURCE_FILE}" ]; then exit 2; fi; shift 2 ;;
    --cors-origin-host) CORS_ORIGIN_HOST="${2}"; shift 2 ;;
    --req-header-host) REQ_HEADER_HOST="${2}"; shift 2 ;;
    --user|-u) TEST_USER="${2}"; shift 2 ;;
    --*=|-*) echo -e "Error: Unsupported flag $1" >&2; exit 1 ;;
    *) PARAMS="$PARAMS $1"; shift ;;
  esac
done

eval set -- "$PARAMS"

if [ -z "${1}" ]; then
  echo -e "Error: you must provide the docker image to test"
  exit 4
fi

DOCKER_IMAGE=${1}

if [ -n "${2}" ]; then
  DOCKER_TEST_IMAGE=${2}
fi

if [ $DRY_RUN -eq 1 ]; then
  print_dry_run
  exit 0
fi

# Check the expectations
test_eq() {
  if [ "${1:-}" != "${2:-}" ]; then
    TEST_PASSED=0
    LOC_EXIT_STATUS=6
  fi

  [ -n "${3}" ] && TEST_FOR=" ${3}" || TEST_FOR=""
  [ $TEST_PASSED -eq 1 ] && TEST_PASSED_STR="\e[32mOK\e[39m" || TEST_PASSED_STR="\e[31mFAIL\e[39m"
  echo -e "Testing the expectation for${TEST_FOR}: ${TEST_PASSED_STR}"
  if [ $TEST_PASSED -ne 1 ]; then
    echo -e "Expected: ${2} - Actual value: ${1}"
    echo -e ""
  fi

  return $LOC_EXIT_STATUS
}
test_rex () {
  # shellcheck disable=SC2126
  if [ "$(echo -e "${1:-}" | grep -E "${2:-}" | wc -l)" -ne 1 ]; then
    TEST_PASSED=0
    LOC_EXIT_STATUS=6
  fi

  [ -n "${3}" ] && TEST_FOR=" ${3}" || TEST_FOR=""
  [ $TEST_PASSED -eq 1 ] && TEST_PASSED_STR="\e[32mOK\e[39m" || TEST_PASSED_STR="\e[31mFAIL\e[39m"
  echo -e "Testing the expectation for${TEST_FOR}: ${TEST_PASSED_STR}"
  if [ $TEST_PASSED -ne 1 ]; then
    echo -e "Expected: ${2} - Actual value: ${1}"
    echo -e ""
  fi

  return $LOC_EXIT_STATUS
}
test_for_body_response() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    test_eq "${DOCKER_TEST_BODY_RES}" "${CUR_TEST_VAL}" "Response Body"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt "$EXIT_STATUS" ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}
test_for_body_request() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    test_eq "${DOCKER_TEST_BODY_REQ}" "${CUR_TEST_VAL}" "Request Body"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}
test_for_header_response() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAR}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(echo -e "${DOCKER_TEST_HEADER_RES}" | grep "^${CUR_TEST_VAR}: " | awk -F': ' '{gsub(/\r/,""); print $2}')
    test_rex "${CONTAINER_VAL}" "${CUR_TEST_VAL:-}" "Response Header ${CUR_TEST_VAR}"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}
test_for_header_request() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAR}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(echo -e "${DOCKER_TEST_HEADER_REQ}" | grep "^${CUR_TEST_VAR}: " | awk -F': ' '{gsub(/\r/,""); print $2}')
    test_eq "${CONTAINER_VAL}" "${CUR_TEST_VAL:-}" "Request Header ${CUR_TEST_VAR}"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}
test_for_http_status() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(echo -e "${DOCKER_TEST_HEADER_RES}" | grep "^HTTP/1.1 ${CUR_TEST_VAL}" | awk -F': ' '{gsub(/\r/,""); print $0}')
    test_eq "${CONTAINER_VAL}" "HTTP/1.1 ${CUR_TEST_VAL}" "HTTP Status Header"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}
test_for_user() {
  LOC_EXIT_STATUS=5
  if [ -n "${CONTAINER_ID}" ] && [ -n "${CUR_TEST_VAL}" ]; then
    TEST_USER=""
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(docker exec "${CONTAINER_ID}" ash -c "whoami 2>&1 | sed 's/whoami: //'")
    test_eq "${CONTAINER_VAL}" "${CUR_TEST_VAL}" "User"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
      EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}

if [ -z "$(docker images -q "${DOCKER_IMAGE}")" ]; then
  echo -e "Failed to find the docker image: ${DOCKER_IMAGE}"
  exit 7
fi

# The test image is a public image, so the test below is not needed
# if [ -z "$(docker images -q ${DOCKER_TEST_IMAGE})" ]; then
#   echo -e "Failed to find the docker test image: ${DOCKER_TEST_IMAGE}"
#   exit 8
# fi

echo -e "Start testing process on image: ${DOCKER_IMAGE} ..."

EXIT_STATUS=0

if [ "${PHP_IS_NEEDED}" -eq 1 ]; then
  # Start a container for php to use for FPM purpose
  debug "Start php-fpm container for test purpose"
  debug "Docker run command: docker run --rm ${DOCKER_ENV} -d -w /var/www/html -v ${PWD}/tests/html:/var/www/html ${DOCKER_PHP_IMAGE}"
  # shellcheck disable=SC2086
  PHP_CONTAINER_ID=$(docker run --rm ${DOCKER_ENV} -d -w /var/www/html -v ${PWD}/tests/html:/var/www/html ${DOCKER_PHP_IMAGE})
  #shellcheck disable=SC2181
  if [ $? -ne 0 ]; then
    echo -e "Failed to start the docker image (PHP)"
    docker logs "${PHP_CONTAINER_ID}"
    exit 9
  fi
  debug "Find the container IP address (PHP): docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${PHP_CONTAINER_ID}"
  DOCKER_PHP_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${PHP_CONTAINER_ID}")
  #shellcheck disable=SC2181
  if [ $? -ne 0 ] || [ -z "${DOCKER_PHP_IP}" ]; then
    echo -e "Failed to discover the IP address of the docker image (PHP)"
    docker logs "${PHP_CONTAINER_ID}"
    exit 10
  fi
  # Add the PHP_HOST as additional env var to be used as php upstream
  if [ -n "${ENV_LIST}" ]; then
    ENV_LIST="${ENV_LIST},PHP_HOST=${DOCKER_PHP_IP}"
  else
    ENV_LIST="PHP_HOST=${DOCKER_PHP_IP}"
  fi
fi

process_docker_env

# Start the nginx container, the real one to test
debug "Docker run command: docker run --rm ${DOCKER_ENV} -d -v ${PWD}/tests/html:/var/www/html ${DOCKER_IMAGE}"
# shellcheck disable=SC2086
CONTAINER_ID=$(docker run --rm ${DOCKER_ENV} -d -v ${PWD}/tests/html:/var/www/html ${DOCKER_IMAGE})
#shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  echo -e "Failed to start the docker image (NGINX)"
  docker logs "${CONTAINER_ID}"
  exit 9
fi

debug "I will perform the tests on the container with id: ${CONTAINER_ID}"

debug "Find the container IP address: docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID}"
DOCKER_TEST_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CONTAINER_ID}")
#shellcheck disable=SC2181
if [ $? -ne 0 ] || [ -z "${DOCKER_TEST_IP}" ]; then
  echo -e "Failed to discover the IP address of the docker image"
  docker logs "${CONTAINER_ID}"
  exit 10
fi

HTTPIE_HOST_HEADER=""
if [ -n "${REQ_HEADER_HOST}" ];then
  HTTPIE_HOST_HEADER="host:${REQ_HEADER_HOST}"
fi

debug "Get the data: docker run --rm ${DOCKER_TEST_IMAGE} --ignore-stdin -p HhBb GET ${DOCKER_TEST_PROTO}://${DOCKER_TEST_IP}:${DOCKER_TEST_PORT}/${DOCKER_TEST_PATH} origin:http://${CORS_ORIGIN_HOST} ${HTTPIE_HOST_HEADER}"
# shellcheck disable=SC2086
DOCKER_TEST_OUTPUT=$(docker run --rm ${DOCKER_TEST_IMAGE} --ignore-stdin -p HhBb GET "${DOCKER_TEST_PROTO}://${DOCKER_TEST_IP}:${DOCKER_TEST_PORT}/${DOCKER_TEST_PATH}" origin:http://${CORS_ORIGIN_HOST} ${HTTPIE_HOST_HEADER})
#shellcheck disable=SC2181
if [ $? -ne 0 ]; then
  echo -e "Failed to get the data"
  exit 11
fi

LINE_POS=0
LINE_VAL=""
SEP="~~~~~~~"
EMPTY_PLACEHOLDER="~~~EMPTY~~~"
OLD_IFS=$IFS
IFS="$(printf '\nx')" && IFS="${IFS%x}";
for line in $(echo -e "${DOCKER_TEST_OUTPUT}" | tr -d '\r' | sed 's/^$/'${SEP}'/g'); do
  if [ "${line}" = "${SEP}" ]; then

    [ "${LINE_VAL}" = "${EMPTY_PLACEHOLDER}\n" ] && SAVE_LINE_VAL="\n" || SAVE_LINE_VAL="${LINE_VAL}"
    if [ $LINE_POS -eq 0 ]; then
      DOCKER_TEST_HEADER_REQ="${SAVE_LINE_VAL%??}"
    elif [ $LINE_POS -eq 1 ]; then
      DOCKER_TEST_BODY_REQ="${SAVE_LINE_VAL%??}"
    elif [ $LINE_POS -eq 2 ]; then
      DOCKER_TEST_HEADER_RES="${SAVE_LINE_VAL%??}"
    elif [ $LINE_POS -eq 3 ]; then
      DOCKER_TEST_BODY_RES="${SAVE_LINE_VAL%??}"
    fi

    if [ -n "${LINE_VAL}" ]; then
      #shellcheck disable=SC2004
      LINE_POS=$(($LINE_POS + 1))
      LINE_VAL=""
    else
      LINE_VAL="${EMPTY_PLACEHOLDER}\n"
    fi
  else
    LINE_VAL="${LINE_VAL}${line}\n"
  fi
done

if [ $LINE_POS -eq 3 ]; then
  DOCKER_TEST_BODY_RES="${LINE_VAL%??}"
fi
IFS=$OLD_IFS

if [ -f "${SOURCE_FILE}" ]; then
  while read -r line || [ -n "$line" ]; do
    if [ "${line}" = "$(echo -e "${line}" | tr -d '#')" ]; then
      CUR_TEST_VAR=$(echo -e "${line}" | awk -F'=' '{print $1}')
      CUR_TEST_VAL=$(echo -e "${line}" | awk -F'=' '{for (i=2; i<NF; i++) printf $i "="; print $NF;}' | sed 's/"//g')

      PRINT_VAR=""
      if [ "${CUR_TEST_VAR}" = "HTTP_STATUS" ]; then
        test_for_http_status
      elif [ "${CUR_TEST_VAR}" = "BODY_RES" ]; then
        test_for_body_response
      elif [ "${CUR_TEST_VAR}" = "BODY_REQ" ]; then
        test_for_body_request
      elif [ "$(echo -e "${CUR_TEST_VAR}" | awk '$0 ~ /^HEADER_RES_/ {print 1}')" = "1" ]; then
        CUR_TEST_VAR=$(echo -e "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_RES_/,""); print $0}')
        test_for_header_response
      elif [ "$(echo -e "${CUR_TEST_VAR}" | awk '$0 ~ /^HEADER_REQ_/ {print 1}')" = "1" ]; then
        CUR_TEST_VAR=$(echo -e "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_REQ_/,""); print $0}')
        test_for_header_request
      fi

      debug "CUR_TEST_VAR: ${CUR_TEST_VAR}"
      debug "CUR_TEST_VAL: ${CUR_TEST_VAL}"
    fi
  done < "${SOURCE_FILE}"
fi

if [ -n "${TEST_USER}" ]; then
  CUR_TEST_VAL="${TEST_USER}"
  test_for_user
fi

debug "Docker stop command: docker stop ${CONTAINER_ID} >/dev/null 2>&1"
docker stop "${CONTAINER_ID}" >/dev/null 2>&1

if [ "${PHP_IS_NEEDED}" -eq 1 ]; then
  debug "Docker stop command (PHP): docker stop ${PHP_CONTAINER_ID} >/dev/null 2>&1"
  docker stop "${PHP_CONTAINER_ID}" >/dev/null 2>&1
fi

if [ $EXIT_STATUS -eq 0 ]; then
  echo -e "\e[32mSUCCESS, all tests passed\e[39m"
else
  echo -e "\e[31mFAIL, some tests failed\e[39m"
fi

debug "HEADER REQ"
debug "${DOCKER_TEST_HEADER_REQ}"
debug "BODY REQ"
debug "${DOCKER_TEST_BODY_REQ}"
debug "HEADER RES"
debug "${DOCKER_TEST_HEADER_RES}"
debug "BODY RES"
debug "${DOCKER_TEST_BODY_RES}"

exit $EXIT_STATUS
