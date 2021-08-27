#!/bin/sh

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

DEBUG=${DEBUG:-0}
DRY_RUN=0

DOCKER_TEST_IMAGE="alpine/httpie:latest"
DOCKER_TEST_IP=""
DOCKER_TEST_PORT=80
DOCKER_TEST_PROTO="http"

DOCKER_TEST_OUTPUT=""
DOCKER_TEST_HEADER_REQ=""
DOCKER_TEST_HEADER_RES=""
DOCKER_TEST_BODY_REQ=""
DOCKER_TEST_BODY_RES=""

DOCKER_IMAGE=""
DOCKER_ENV=""
ENV_LIST=""
ENV_FILE=""

SOURCE_FILE=""

CUR_TEST_VAR=""
CUR_TEST_VAL=""

CORS_ORIGIN_HOST=${CORS_ORIGIN_HOST:-"www.example.com"}

print_dry_run() {
  PAD=60
  cat <<EOM
You are running this script in dry-run mode.
I will test the defined expectations as defined below:

### Generic variables ###
EOM
printf "%-${PAD}s %s\n" "DOCKER_TEST_IMAGE" "${DOCKER_TEST_IMAGE}"
printf "%-${PAD}s %s\n" "DOCKER_IMAGE" "${DOCKER_IMAGE}"
printf "%-${PAD}s %s\n" "PORT" "${DOCKER_TEST_PORT}"
printf "%-${PAD}s %s\n" "PROTO" "${DOCKER_TEST_PROTO}"
printf "%-${PAD}s %s\n" "ENV_LIST" "${ENV_LIST}"
printf "%-${PAD}s %s\n" "ENV_FILE" "${ENV_FILE}"
printf "%-${PAD}s %s\n" "SOURCE_FILE" "${SOURCE_FILE}"

if [ -n "${TEST_USER}" ]; then
    printf "%-${PAD}s %s\n" "CONTAINER_USER" "${TEST_USER}"
fi

cat <<EOM

### Defined variables ###
EOM
  while read -r line || [ -n "$line" ]; do
    if [ "${line}" = "$(echo "${line}" | tr -d '#')" ]; then
      CUR_TEST_VAR=$(echo "${line}" | awk '{split($0,a,"="); print a[1]}')
      CUR_TEST_VAL=$(echo "${line}" | awk '{gsub(/"/,""); split($0,a,"="); print a[2]}')

      PRINT_VAR=""
      if [ "${CUR_TEST_VAR}" = "HTTP_STATUS" ]; then
        PRINT_VAR="HTTP Status Header"
      elif [ "${CUR_TEST_VAR}" = "BODY_RES" ]; then
        PRINT_VAR="Body response"
      elif [ "${CUR_TEST_VAR}" = "BODY_REQ" ]; then
        PRINT_VAR="Body request"
      elif [ "$(echo ${CUR_TEST_VAR} | awk '$0 ~ /^HEADER_RES_/ {print 1}')" = "1" ]; then
        PRINT_VAR="Header response $(echo "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_RES_/,""); print $0}')"
      elif [ "$(echo ${CUR_TEST_VAR} | awk '$0 ~ /^HEADER_REQ_/ {print 1}')" = "1" ]; then
        PRINT_VAR="Header request $(echo "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_REQ_/,""); print $0}')"
      fi

      if [ -n "${PRINT_VAR}" ]; then
        printf "%-${PAD}s %s\n" "${PRINT_VAR}" "${CUR_TEST_VAL}"
      fi
    fi
  done < ${SOURCE_FILE}
}

show_usage() {
  cat <<EOM
Usage: $(basename $0) [OPTIONS] [EXPECTATIONS] <DOCKER IMAGE> [DOCKER TEST IMAGE]
Options:
  --help,-h                           Print this help message
  --dry-run                           The script will only print the expectations
  --env,-e LIST                       Defines the comma separated environment variables to pass to the container
  --env-file PATH                     Defines a path for a file which includes all the ENV variables to pass to
                                      the container image (these variables will override the --env defined ones)
  --http-port N                       Defines the HTTP port, if missing the default 80 port is used
  --http-proto STRING [http|https]    Defines the HTTP protocol to use, if missing the default http is used
  --source PATH                       Defines a path for a file which includes the desired expectations
  --user,-u STRING                    Defines the default user for the image
EOM
}

process_docker_env() {
  if [ -n "${ENV_LIST}" ]; then
    DOCKER_ENV="-e $(echo "${ENV_LIST}" | sed 's/,/ -e /g;')"
  fi
  if [ -n "${ENV_FILE}" ]; then
    if [ -f "${ENV_FILE}" ]; then
      DOCKER_ENV="${DOCKER_ENV} --env-file ${ENV_FILE}"
    else
      echo "Failed to process the env configuration"
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
    --env|-e) if [ -n "${ENV_LIST}" ]; then ENV_LIST="${ENV_LIST},${2}"; else ENV_LIST="${2}"; fi; shift 2 ;;
    --env-file) ENV_FILE="${2}"; if [ ! -f "${ENV_FILE}" ]; then exit 3; fi; shift 2 ;;
    --http-port) DOCKER_TEST_PORT="${2}"; shift 2 ;;
    --http-proto) DOCKER_TEST_PROTO="${2}"; shift 2 ;;
    --source) SOURCE_FILE="${2}"; if [ ! -f "${SOURCE_FILE}" ]; then exit 2; fi; shift 2 ;;
    --user|-u) TEST_USER="${2}"; shift 2 ;;
    -*|--*=) echo "Error: Unsupported flag $1" >&2; exit 1 ;;
    *) PARAMS="$PARAMS $1"; shift ;;
  esac
done

eval set -- "$PARAMS"

if [ -z "${1}" ]; then
  echo "Error: you must provide the docker image to test"
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
  if [ -n "${1}" ] && [ -n "${2}" ]; then
    if [ "${1}" != "${2}" ]; then
      TEST_PASSED=0
      LOC_EXIT_STATUS=6
    fi

    [ -n "${3}" ] && TEST_FOR=" ${3}" || TEST_FOR=""
    [ $TEST_PASSED -eq 1 ] && TEST_PASSED_STR="\e[32mOK\e[39m" || TEST_PASSED_STR="\e[31mFAIL\e[39m"
    echo "Testing the expectation for${TEST_FOR}: ${TEST_PASSED_STR}"
    if [ $TEST_PASSED -ne 1 ]; then
      echo "Expected: ${2} - Actual value: ${1}"
      echo ""
    fi

    return $LOC_EXIT_STATUS
  fi

  TEST_PASSED=0
  LOC_EXIT_STATUS=6
  return $LOC_EXIT_STATUS
}
test_for_body_response() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    test_eq "${DOCKER_TEST_BODY_RES}" "${CUR_TEST_VAL}" "Response Body"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
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
  if [ -n "${CUR_TEST_VAR}" ] && [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(echo "${DOCKER_TEST_HEADER_RES}" | grep "^${CUR_TEST_VAR}: " | awk '{gsub(/\r/,""); print $2}')
    test_eq "${CONTAINER_VAL}" "${CUR_TEST_VAL}" "Response Header ${CUR_TEST_VAR}"
  fi

  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
    EXIT_STATUS=$LOC_EXIT_STATUS
  fi
  
  return $LOC_EXIT_STATUS
}
test_for_header_request() {
  LOC_EXIT_STATUS=5
  if [ -n "${CUR_TEST_VAR}" ] && [ -n "${CUR_TEST_VAL}" ]; then
    LOC_EXIT_STATUS=0
    TEST_PASSED=1
    CONTAINER_VAL=$(echo "${DOCKER_TEST_HEADER_REQ}" | grep "^${CUR_TEST_VAR}: " | awk '{gsub(/\r/,""); print $2}')
    test_eq "${CONTAINER_VAL}" "${CUR_TEST_VAL}" "Request Header ${CUR_TEST_VAR}"
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
    CONTAINER_VAL=$(echo "${DOCKER_TEST_HEADER_RES}" | grep "^HTTP/1.1 ${CUR_TEST_VAL}" | awk '{gsub(/\r/,""); print $0}')
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
    CONTAINER_VAL=$(docker exec ${CONTAINER_ID} ash -c "whoami 2>&1 | sed 's/whoami: //'")
    test_eq "${CONTAINER_VAL}" "${CUR_TEST_VAL}" "User"
  fi
  
  if [ $LOC_EXIT_STATUS -ne 0 ] && [ $LOC_EXIT_STATUS -gt $EXIT_STATUS ]; then
      EXIT_STATUS=$LOC_EXIT_STATUS
  fi

  return $LOC_EXIT_STATUS
}

if [ -z "$(docker images -q ${DOCKER_IMAGE})" ]; then
  echo "Failed to find the docker image: ${DOCKER_IMAGE}"
  exit 7
fi

# The test image is a public image, so the test below is not needed
# if [ -z "$(docker images -q ${DOCKER_TEST_IMAGE})" ]; then
#   echo "Failed to find the docker test image: ${DOCKER_TEST_IMAGE}"
#   exit 8
# fi

echo "Start testing process on image: ${DOCKER_IMAGE} ..."

EXIT_STATUS=0

process_docker_env
if [ $DEBUG -eq 1 ]; then
  echo "Docker run command: docker run ${DOCKER_ENV} --rm -d -v ${PWD}/tests/html:/var/www/html ${DOCKER_IMAGE}"
fi
CONTAINER_ID=$(docker run ${DOCKER_ENV} --rm -d -v ${PWD}/tests/html:/var/www/html ${DOCKER_IMAGE})
if [ $? -ne 0 ]; then
  echo "Failed to start the docker image"
  exit 9
fi

if [ $DEBUG -eq 1 ]; then
  echo "I will perform the tests on the container with id: ${CONTAINER_ID}"
fi

if [ $DEBUG -eq 1 ]; then
  echo "Find the container IP address: docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID}"
fi
DOCKER_TEST_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID})
if [ $? -ne 0 ]; then
  echo "Failed to discover the IP address of the docker image"
  exit 10
fi

if [ $DEBUG -eq 1 ]; then
  echo "Get the data: docker run --rm ${DOCKER_TEST_IMAGE} --ignore-stdin -p HhBb GET ${DOCKER_TEST_PROTO}://${DOCKER_TEST_IP}:${DOCKER_TEST_PORT}/test.html origin:http://${CORS_ORIGIN_HOST}"
fi
DOCKER_TEST_OUTPUT=$(docker run --rm ${DOCKER_TEST_IMAGE} --ignore-stdin -p HhBb GET ${DOCKER_TEST_PROTO}://${DOCKER_TEST_IP}:${DOCKER_TEST_PORT}/test.html origin:http://${CORS_ORIGIN_HOST})
if [ $? -ne 0 ]; then
  echo "Failed to get the data"
  exit 11
fi

LINE_POS=0
LINE_VAL=""
SEP="~~~~~~~"
EMPTY_PLACEHOLDER="~~~EMPTY~~~"
OLD_IFS=$IFS
IFS="$(printf '\nx')" && IFS="${IFS%x}";
for line in $(echo "${DOCKER_TEST_OUTPUT}" | tr -d '\r' | sed 's/^$/'${SEP}'/g'); do
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
    if [ "${line}" = "$(echo "${line}" | tr -d '#')" ]; then
      CUR_TEST_VAR=$(echo "${line}" | awk '{split($0,a,"="); print a[1]}')
      CUR_TEST_VAL=$(echo "${line}" | awk '{gsub(/"/,""); split($0,a,"="); print a[2]}')

      PRINT_VAR=""
      if [ "${CUR_TEST_VAR}" = "HTTP_STATUS" ]; then
        test_for_http_status
      elif [ "${CUR_TEST_VAR}" = "BODY_RES" ]; then
        test_for_body_response
      elif [ "${CUR_TEST_VAR}" = "BODY_REQ" ]; then
        test_for_body_request
      elif [ "$(echo ${CUR_TEST_VAR} | awk '$0 ~ /^HEADER_RES_/ {print 1}')" = "1" ]; then
        CUR_TEST_VAR=$(echo "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_RES_/,""); print $0}')
        test_for_header_response
      elif [ "$(echo ${CUR_TEST_VAR} | awk '$0 ~ /^HEADER_REQ_/ {print 1}')" = "1" ]; then
        CUR_TEST_VAR=$(echo "${CUR_TEST_VAR}" | awk '{gsub(/^HEADER_REQ_/,""); print $0}')
        test_for_header_request
      fi
    fi
  done < ${SOURCE_FILE}
fi

if [ -n "${TEST_USER}" ]; then
  CUR_TEST_VAL="${TEST_USER}"
  test_for_user
fi

if [ $DEBUG -eq 1 ]; then
  echo "Docker stop command: docker stop ${CONTAINER_ID} >/dev/null 2>&1"
fi
docker stop ${CONTAINER_ID} >/dev/null 2>&1

if [ $EXIT_STATUS -eq 0 ]; then
  echo "\e[32mSUCCESS, all tests passed\e[39m"
else
  echo "\e[31mFAIL, some tests failed\e[39m"
fi

if [ $DEBUG -eq 1 ]; then
  echo "HEADER REQ"
  echo "${DOCKER_TEST_HEADER_REQ}"
  echo "BODY REQ"
  echo "${DOCKER_TEST_BODY_REQ}"
  echo "HEADER RES"
  echo "${DOCKER_TEST_HEADER_RES}"
  echo "BODY RES"
  echo "${DOCKER_TEST_BODY_RES}"
fi

exit $EXIT_STATUS
