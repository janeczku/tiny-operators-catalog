#!/usr/bin/env bash

PROJECT_KEY="field.cattle.io/projectId"
CREATOR_KEY="cattle.io/creator"
CREATOR_RANCHER="norman"

LOG_LEVEL={{ if .Values.debugLog }}debug{{ else }}info{{ end }}
DEFAULT_CLUSTER_PROJECT_ID={{ .Values.defaultProjectId }}
DEFAULT_PROJECT_ID=${DEFAULT_CLUSTER_PROJECT_ID#*:}
if [[ -z "$DEFAULT_PROJECT_ID" ]] || [[ $DEFAULT_PROJECT_ID == $DEFAULT_CLUSTER_PROJECT_ID ]] ; then
  log "invalid project ID: $DEFAULT_CLUSTER_PROJECT_ID" && return 1
fi

function log {
  local msg=$1
  local prio=${2:-info}
  [[ $prio == "info" ]] && echo "${msg}" && return
  [[ $prio == "debug" ]] && [[ $prio == $LOG_LEVEL ]] && echo "[debug] ${msg}"
}

if [[ $1 == "--config" ]] ; then
  cat <<EOF
configVersion: v1
kubernetes:
- name: "OnCreateNamespace"
  apiVersion: v1
  kind: Namespace
  executeHookOnEvent: [ "Added" ]
  executeHookOnSynchronization: true
EOF

else
  type=$(jq -r '.[0].type' $BINDING_CONTEXT_PATH)
  bindingName=$(jq -r '.[0].binding' $BINDING_CONTEXT_PATH)

  if [[ $bindingName != "OnCreateNamespace" ]] ; then
    log "Invoked with unknown binding: $bindingName"
    exit 0
  fi
  
  nsEvent=$(jq -r '.[0].watchEvent' $BINDING_CONTEXT_PATH)
  nsName=$(jq -r '.[0].object.metadata.name' $BINDING_CONTEXT_PATH)
  nsProjectId=$(jq -r '.[0].object.metadata.annotations["'$PROJECT_KEY'"]' $BINDING_CONTEXT_PATH)
  nsCreator=$(jq -r '.[0].object.metadata.labels["'$CREATOR_KEY'"]' $BINDING_CONTEXT_PATH)
  
  log "nsCreator: $nsCreator" debug
  log "nsProjectId: $nsProjectId" debug
  
  # ignore Synchronization for simplicity
  if [[ $type == "Synchronization" ]] ; then
    log "Got Synchronization event for ${bindingName}" debug
    exit 0
  fi
  
  # Ignore namespaces created by Rancher
  if [[ $nsCreator == $CREATOR_RANCHER ]] ; then
    log "Ignoring $nsName created by Rancher" debug
    exit 0
  fi
  
  # Ignore namespaces assigned to a project
  if [[ $nsProjectId != "null" ]] ; then
    log "Ignoring $nsName assigned to projectId $nsProjectId" debug
    exit 0
  fi
  
  log "Assigning $nsName to default project ID $DEFAULT_CLUSTER_PROJECT_ID"
  kubectl patch ns $nsName --type=json -p '[
{"op":"add","path":"/metadata/annotations","value":{"'$PROJECT_KEY'":"'$DEFAULT_CLUSTER_PROJECT_ID'"}},
{"op":"add","path":"/metadata/labels","value":{"'$PROJECT_KEY'":"'$DEFAULT_PROJECT_ID'"}}
]'

fi
