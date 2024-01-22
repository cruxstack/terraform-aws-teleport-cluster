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
  TP_PROXY=${1:?}
  TP_CLUSTER=${2:?}
  TP_GATEWAY_NODE=${3:?}
  TP_GATEWAY_USER=${4:-root}

  TUNNEL_GATEWAY_HOST=$(
    tsh ls --proxy "${TP_PROXY}" --cluster "${TP_CLUSTER}" \
    --query="labels[\"service\"] == \"${TP_GATEWAY_NODE}\"" \
    --format names | head -n 1
  )
  echo "${TP_GATEWAY_USER}@${TUNNEL_GATEWAY_HOST}"
}

function open_background_tunnel() {
  TP_PROXY=${1:?}
  TP_CLUSTER=${2:?}
  TUNNEL_LOCAL_PORT=${3:?}
  TUNNEL_TARGET_HOST=${4:?}
  TUNNEL_TARGET_PORT=${5:?}
  TUNNEL_GATEWAY_ADDRESS=${6:?}

  tsh ssh --proxy "${TP_PROXY}" --cluster "${TP_CLUSTER}" \
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
  TP_PROXY=${1:?}
  TP_CLUSTER=${2:?}
  TUNNEL_LOCAL_PORT=${3:?}
  TUNNEL_TARGET_HOST=${4:?}
  TUNNEL_TARGET_PORT=${5:?}
  TUNNEL_GATEWAY_ADDRESS=${6:?}
  TUNNEL_TIMEOUT=${6:-$TUNNEL_TIMEOUT}

  PARENT_PROCESS_ID="$(ps -p "${PPID}" -o "ppid=")"

  CHILD_PROCRESS_LOG=$(mktemp)
  nohup timeout "${TUNNEL_TIMEOUT}" \
    "${SCRIPT_ROOT}/tunneler.sh" \
    "open_background_tunnel" \
    "${TP_PROXY}" \
    "${TP_CLUSTER}" \
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
  TP_PROXY=${1:?}
  TP_CLUSTER=${2:?}
  TP_GATEWAY_NODE=${3:?}
  TUNNEL_TARGET_HOST=${4:?}
  TUNNEL_TARGET_PORT=${5:?}

  TUNNEL_LOCAL_PORT=$(get_random_ephemeral_port)
  TUNNEL_GATEWAY_ADDRESS=$(get_gateway_address "${TP_PROXY}" "${TP_CLUSTER}" "${TP_GATEWAY_NODE}")

  open_background_tunnel_with_timeout \
    "${TP_PROXY}" \
    "${TP_CLUSTER}" \
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
    TP_PROXY=$(echo "${INPUT}" | jq -r .tp_proxy)
    TP_CLUSTER=$(echo "${INPUT}" | jq -r .tp_cluster)
    TP_GATEWAY_NODE=$(echo "${INPUT}" | jq -r .tp_gateway_node)
    TARGET_HOST=$(echo "${INPUT}" | jq -r .target_host)
    TARGET_PORT=$(echo "${INPUT}" | jq -r .target_port)

    LOCAL_PORT=$(create "${TP_PROXY}" "${TP_CLUSTER}" "${TP_GATEWAY_NODE}" "${TARGET_HOST}" "${TARGET_PORT}")
    echo "{\"host\":\"localhost\",\"port\":\"${LOCAL_PORT}\"}"

elif [[ "${1}" == "create" ]]; then

    # handler for normal cli calls

    shift

    LOCAL_PORT=$(create "${@}")
    echo "localhost:${LOCAL_PORT}"

else

  COMMAND=${1:?}
  COMMAND=${COMMAND//-/_} # convert dashes to unders
  shift

  "${COMMAND}" "${@}"

fi

exit "${SCRIPT_EXIT_CODE}"
