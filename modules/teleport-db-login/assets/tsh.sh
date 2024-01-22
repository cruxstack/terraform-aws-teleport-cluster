#!/usr/bin/env bash
SCRIPT_EXIT_CODE=0

# --------------------------------------------------------------------- main ---

function db_login() {
  TP_PROXY=${1:?}
  TP_CLUSTER=${2:?}
  TARGET_DB=${3:?}
  TARGET_DB_NAME=${4}
  TARGET_DB_USER=${5}

  tsh db login --proxy "${TP_PROXY}" --cluster "${TP_CLUSTER}" "${TARGET_DB}" --db-name "${TARGET_DB_NAME:-"unset_db"}" --db-user "${TARGET_DB_USER:-"unset_user"}" 1>/dev/null
  tsh db config --proxy "${TP_PROXY}" --cluster "${TP_CLUSTER}" "${TARGET_DB}" --format=json
}

# ------------------------------------------------------------------- script ---

if [[ "${1}" == "db-login" && "${2}" == "stdin" ]]; then

    INPUT="$(dd 2>/dev/null)"

    TP_PROXY=$(echo "${INPUT}" | jq -r .tp_proxy)
    TP_CLUSTER=$(echo "${INPUT}" | jq -r .tp_cluster)
    TARGET_DB=$(echo "${INPUT}" | jq -r .target_db)
    TARGET_DB_NAME=$(echo "${INPUT}" | jq -r .target_db_name)
    TARGET_DB_USER=$(echo "${INPUT}" | jq -r .target_db_user)

    db_login "${TP_PROXY}" "${TP_CLUSTER}" "${TARGET_DB}" "${TARGET_DB_NAME}" "${TARGET_DB_USER}" | jq 'walk(if type =="number" then tostring else . end)' | jq -c .

else

  COMMAND=${1:?}
  COMMAND=${COMMAND//-/_} # convert dashes to unders
  shift

  "${COMMAND}" "${@}"

fi

exit "${SCRIPT_EXIT_CODE}"
