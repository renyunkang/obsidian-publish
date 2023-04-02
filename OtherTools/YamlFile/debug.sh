#!/usr/bin/env bash

# Before debugging you should add the ip address of the host to '--host=' in the openelb-admission-create job.
HOSTNAME=$(hostname)
NAMESPACE=${NAMESPACE:-'openelb-system'}
SECRET_NAME=${SECRET_NAME:-'openelb-admission'}
DATA_PATH=${DATA_PATH:-'/tmp/k8s-webhook-server/serving-certs'}

REPLACE=${REPLACE:-false}
HOST_IP=${HOST_IP:-'172.31.1.6'}
HOST_PORT=${HOST_PORT:-'443'}
WEBHOOK_NAME=${WEBHOOK_NAME:-$SECRET_NAME}
VALIDATE_URL=${VALIDATE_URL:-'validate-network-kubesphere-io-v1alpha2-eip'}
MUTATE_URL=${MUTATE_URL:-'validate-network-kubesphere-io-v1alpha2-svc'}

cat > /etc/profile.d/openelb.sh << EOF
export NODE_NAME=$HOSTNAME
export OPENELB_NAMESPACE=$NAMESPACE
EOF
source /etc/profile

mkdir -p $DATA_PATH
kubectl scale --replicas=0 deployment/openelb-manager -n $NAMESPACE
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.cert}'| base64 --decode > $DATA_PATH/tls.crt
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.key}'| base64 --decode > $DATA_PATH/tls.key
kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.ca}'| base64 --decode > $DATA_PATH/ca.crt

validate_value="https://$HOST_IP:$HOST_PORT/$VALIDATE_URL"
mutate_value="https://$HOST_IP:$HOST_PORT/$MUTATE_URL"
if [ "$REPLACE" == "true" ]; then
  kubectl patch validatingwebhookconfigurations $WEBHOOK_NAME -n $NAMESPACE --type='json' -p '[{"op":"replace","path":"/webhooks/0/clientConfig/url","value":'${validate_value}'}]'
  kubectl patch mutatingwebhookconfigurations $WEBHOOK_NAME -n $NAMESPACE --type='json' -p '[{"op":"replace","path":"/webhooks/0/clientConfig/url","value":'${mutate_value}'}]'
else
  kubectl patch validatingwebhookconfigurations $WEBHOOK_NAME -n $NAMESPACE --type='json' -p '[{"op":"remove","path":"/webhooks/0/clientConfig/service"},{"op":"replace","path":"/webhooks/0/clientConfig/url","value":'${validate_value}'}]'
  kubectl patch mutatingwebhookconfigurations $WEBHOOK_NAME -n $NAMESPACE --type='json' -p '[{"op":"remove","path":"/webhooks/0/clientConfig/service"},{"op":"replace","path":"/webhooks/0/clientConfig/url","value":'${mutate_value}'}]'
fi
echo "start debug by follow command:"
echo "  dlv --listen=:2345 --headless=true --api-version=2 exec ./demo"