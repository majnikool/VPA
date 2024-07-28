#!/bin/bash

# Define your desired namespace selector
NAMESPACE_SELECTOR='{"matchExpressions":[{"key":"vpa","operator":"NotIn","values":["disabled"]}]}' 

# Get list of mutating webhook configurations and update if necessary
for webhook in $(kubectl get mutatingwebhookconfigurations -o json | jq -r '.items[].metadata.name'); do
  echo "Updating $webhook mutating webhook configuration..."
  WEBHOOK_COUNT=$(kubectl get mutatingwebhookconfigurations $webhook -o json | jq '.webhooks | length')
  for i in $(seq 0 $(($WEBHOOK_COUNT-1))); do
    if kubectl get mutatingwebhookconfigurations $webhook -o json | jq -e ".webhooks[$i].namespaceSelector" > /dev/null; then
      # namespaceSelector exists, replace it
      kubectl patch mutatingwebhookconfigurations $webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/$i/namespaceSelector', 'value': $NAMESPACE_SELECTOR }]"
    else
      # namespaceSelector doesn't exist, add it
      kubectl patch mutatingwebhookconfigurations $webhook --type='json' -p="[{'op': 'add', 'path': '/webhooks/$i/namespaceSelector', 'value': $NAMESPACE_SELECTOR }]"
    fi
  done
done

# Get list of validating webhook configurations and update if necessary
for webhook in $(kubectl get validatingwebhookconfigurations -o json | jq -r '.items[].metadata.name'); do
  echo "Updating $webhook validating webhook configuration..."
  WEBHOOK_COUNT=$(kubectl get validatingwebhookconfigurations $webhook -o json | jq '.webhooks | length')
  for i in $(seq 0 $(($WEBHOOK_COUNT-1))); do
    if kubectl get validatingwebhookconfigurations $webhook -o json | jq -e ".webhooks[$i].namespaceSelector" > /dev/null; then
      # namespaceSelector exists, replace it
      kubectl patch validatingwebhookconfigurations $webhook --type='json' -p="[{'op': 'replace', 'path': '/webhooks/$i/namespaceSelector', 'value': $NAMESPACE_SELECTOR }]"
    else
      # namespaceSelector doesn't exist, add it
      kubectl patch validatingwebhookconfigurations $webhook --type='json' -p="[{'op': 'add', 'path': '/webhooks/$i/namespaceSelector', 'value': $NAMESPACE_SELECTOR }]"
    fi
  done
done

