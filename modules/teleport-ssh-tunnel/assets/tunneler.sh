#!/usr/bin/env bash
# shellcheck disable=SC2317

SCRIPT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/" &> /dev/null && pwd )"
SCRIPT_EXIT_CODE=0

TUNNEL_TIMEOUT=20m

# ---------------------------------------------------------------------- fns ---

function check_process_exists {
  ps -p "${1}" >/dev/null 2>&1 && echo "true" || echo "false"
}

function get_random_ephemeral_port() {
  LOWER_BOUND=49152
  UPPER_BOUND=65000
  while true; do
    CANDIDATE_PORT=$(( LOWER_BOUND + (RANDOM % (UPPER_BOUND - LOWER_BOUND)) ))
    if ! (echo -n "" >/dev/tcp/127.0.0.1/"${CANDIDATE_PORT}") >/dev/null 2>&1; then
      # return port number if open
      echo "${CANDIDATE_PORT}" && break
    fi
  done
}

function get_gateway_address() {
  TELEPORT_CLUSTER=${1:?}
  TELEPORT_GATEWAY_NAME=${2:?}

  NODE_HOST=$(
    tsh ls --cluster "${TELEPORT_CLUSTER}" \
    --query="labels[\"service\"] == \"${TELEPORT_GATEWAY_NAME}\"" \
    --format names | head -n 1
  )
  echo "root@${NODE_HOST}"
}

function open_tunnel() {
  TSH_CLUSTER_NAME=${1:?}
  TUNNEL_LOCAL_PORT=${2:?}
  TUNNEL_TARGET_HOST=${3:?}
  TUNNEL_TARGET_PORT=${4:?}
  TUNNEL_GATEWAY_ADDRESS=${5:?}

  tsh ssh --cluster "${TSH_CLUSTER_NAME}" \
    -N -L "${TUNNEL_LOCAL_PORT}:${TUNNEL_TARGET_HOST}:${TUNNEL_TARGET_PORT}" \
    "${TUNNEL_GATEWAY_ADDRESS}"
}

function open_background_tunnel() {
  TSH_CLUSTER_NAME=${1:?}
  TUNNEL_LOCAL_PORT=${2:?}
  TUNNEL_TARGET_HOST=${3:?}
  TUNNEL_TARGET_PORT=${4:?}
  TUNNEL_GATEWAY_ADDRESS=${5:?}

  tsh ssh --cluster "${TSH_CLUSTER_NAME}" \
    -N -L "${TUNNEL_LOCAL_PORT}:${TUNNEL_TARGET_HOST}:${TUNNEL_TARGET_PORT}" \
    "${TUNNEL_GATEWAY_ADDRESS}" &
  TUNNEL_PID=$!

  sleep 0

  while true ; do
    if [[ "$(check_process_exists "${TUNNEL_PID}")" == "false" ]] ; then
      echo "ERROR: tsh ssh tunnel process (${TUNNEL_PID}) failed" >&2
      exit 1
    fi
    sleep 1
  done

  kill "${TUNNEL_PID}"
}

function open_background_tunnel_with_timeout() {
  TSH_CLUSTER_NAME=${1:?}
  TUNNEL_LOCAL_PORT=${2:?}
  TUNNEL_TARGET_HOST=${3:?}
  TUNNEL_TARGET_PORT=${4:?}
  TUNNEL_GATEWAY_ADDRESS=${5:?}
  TUNNEL_TIMEOUT=${6:-$TUNNEL_TIMEOUT}

  PARENT_PROCESS_ID="$(ps -p "${PPID}" -o "ppid=")"

  CHILD_PROCRESS_LOG=$(mktemp)
  nohup timeout "${TUNNEL_TIMEOUT}" \
    "${SCRIPT_ROOT}/tunneler.sh" \
    "open_background_tunnel" \
    "${TSH_CLUSTER_NAME}" \
    "${TUNNEL_LOCAL_PORT}" \
    "${TUNNEL_TARGET_HOST}" \
    "${TUNNEL_TARGET_PORT}" \
    "${TUNNEL_GATEWAY_ADDRESS}" \
    "${PARENT_PROCESS_ID}" \
     <&- >&- 2>"${CHILD_PROCRESS_LOG}" &
  CHILD_PROCESS_ID=$!

  sleep 3

  # throw error if tunnel (child process) is not active
  if [[ "$(check_process_exists "${CHILD_PROCESS_ID}")" == "false" ]]; then
    echo "ERROR: child process (${CHILD_PROCESS_ID}) failed" >&2
    cat "${CHILD_PROCRESS_LOG}" >&2
    SCRIPT_EXIT_CODE=1
  fi
}

# --------------------------------------------------------------------- main ---

function create() {
  TELEPORT_CLUSTER=${1:?}
  TELEPORT_GATEWAY_NAME=${2:?}
  TUNNEL_TARGET_HOST=${3:?}
  TUNNEL_TARGET_PORT=${4:?}

  TUNNEL_LOCAL_PORT=$(get_random_ephemeral_port)
  TUNNEL_GATEWAY_ADDRESS=$(get_gateway_address "${TELEPORT_CLUSTER}" "${TELEPORT_GATEWAY_NAME}")

  open_background_tunnel_with_timeout \
    "${TELEPORT_CLUSTER}" \
    "${TUNNEL_LOCAL_PORT}" \
    "${TUNNEL_TARGET_HOST}" \
    "${TUNNEL_TARGET_PORT}" \
    "${TUNNEL_GATEWAY_ADDRESS}"

  echo "${TUNNEL_LOCAL_PORT}"
}

# ------------------------------------------------------------------- script ---

if [[ "${1}" == "create" && "${2}" == "stdin" ]]; then

    # handler if input is stdin (e.g. from terraform)

    INPUT="$(dd 2>/dev/null)"
    TELEPORT_CLUSTER=$(echo "${INPUT}" | jq -r .teleport_cluster)
    TELEPORT_GATEWAY_NAME=$(echo "${INPUT}" | jq -r .teleport_gateway_name)
    TUNNEL_TARGET_HOST=$(echo "${INPUT}" | jq -r .target_host)
    TUNNEL_TARGET_PORT=$(echo "${INPUT}" | jq -r .target_port)

    TUNNEL_LOCAL_PORT=$(create "${TELEPORT_CLUSTER}" "${TELEPORT_GATEWAY_NAME}" "${TUNNEL_TARGET_HOST}" "${TUNNEL_TARGET_PORT}")
    echo "{\"host\":\"localhost\",\"port\":\"${TUNNEL_LOCAL_PORT}\"}"

elif [[ "${1}" == "create" ]]; then

    # handler for normal cli calls

    shift

    TUNNEL_LOCAL_PORT=$(create "${@}")
    echo "localhost:${TUNNEL_LOCAL_PORT}"

else

  COMMAND=${1:?}
  COMMAND=${COMMAND//-/_} # convert dashes to unders
  shift

  "${COMMAND}" "${@}"

fi

exit "${SCRIPT_EXIT_CODE}"
