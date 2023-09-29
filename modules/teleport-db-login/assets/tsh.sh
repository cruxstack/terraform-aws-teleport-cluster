#!/usr/bin/env bash
SCRIPT_EXIT_CODE=0

# --------------------------------------------------------------------- main ---

function db_login() {
  TSH_TARGET_CLUSTER=${1:?}
  TSH_TARGET_DB=${2:?}

  tsh db login --cluster "${TSH_CLUSTER_NAME}" "${TSH_TARGET_DB}" 1>/dev/null
  tsh db config --cluster "${TSH_CLUSTER_NAME}" --format=json "${TSH_TARGET_DB}"
}

# ------------------------------------------------------------------- script ---

if [[ "${1}" == "db-login" && "${2}" == "stdin" ]]; then

    INPUT="$(dd 2>/dev/null)"
    TSH_TARGET_CLUSTER=$(echo "${INPUT}" | jq -r .target_cluster)
    TSH_TARGET_DB=$(echo "${INPUT}" | jq -r .target_db)


    db_login "${TSH_TARGET_CLUSTER}" "${TSH_TARGET_DB}" | jq 'walk(if type =="number" then tostring else . end)' | jq -c .

else

  COMMAND=${1:?}
  COMMAND=${COMMAND//-/_} # convert dashes to unders
  shift

  "${COMMAND}" "${@}"

fi

exit "${SCRIPT_EXIT_CODE}"
