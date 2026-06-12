#!/usr/bin/env bash
# Atualiza um ECS Service registrando uma nova task definition derivada da atual,
# trocando apenas a imagem do container. Usado pelo fluxo de rollback.
#
# Uso:
#   ./deploy-ecs-image.sh <service-name> <image-uri>

set -euo pipefail

SERVICE="${1:?missing service name}"
IMAGE="${2:?missing image uri}"

CLUSTER_NAME="${CLUSTER_NAME:-kabum-poc-cluster}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"

echo "==> Service:  $SERVICE"
echo "==> Cluster:  $CLUSTER_NAME"
echo "==> Image:    $IMAGE"

# 1. Pega TD atual
aws ecs describe-task-definition --task-definition "$SERVICE" \
  --query 'taskDefinition' --output json > /tmp/td-current.json

# 2. Deriva nova TD
jq --arg img "$IMAGE" --arg cn "$CONTAINER_NAME" '
  .containerDefinitions |= map(if .name == $cn then .image = $img else . end) |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
      .compatibilities, .registeredAt, .registeredBy)
' /tmp/td-current.json > /tmp/td-new.json

# 3. Registra (sem usar /dev/stdin, que não funciona no AWS CLI v2 em todos os ambientes)
NEW_ARN=$(aws ecs register-task-definition \
  --cli-input-json "file:///tmp/td-new.json" \
  --query 'taskDefinition.taskDefinitionArn' --output text)
echo "==> New TD: $NEW_ARN"

# 4. Atualiza service
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE" \
  --task-definition "$NEW_ARN" \
  --query 'service.{name:serviceName,td:taskDefinition,desired:desiredCount,running:runningCount}' \
  --output table

echo "==> Aguardando estabilização (até 5min)…"
aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE"
echo "==> Service $SERVICE estável."
