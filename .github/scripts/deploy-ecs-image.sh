#!/usr/bin/env bash
# Atualiza um ECS Service registrando uma nova task definition derivada da atual,
# trocando apenas a imagem do container. Mantém todas as demais propriedades.
#
# Uso:
#   ./deploy-ecs-image.sh <service-name> <image-uri>
#
# Variáveis de ambiente esperadas:
#   AWS_REGION       (ex: us-east-1)
#   CLUSTER_NAME     (ex: kabum-poc-cluster)
#   CONTAINER_NAME   (ex: app)

set -euo pipefail

SERVICE="${1:?missing service name}"
IMAGE="${2:?missing image uri}"

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-kabum-poc-cluster}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"

echo "==> Service:  $SERVICE"
echo "==> Cluster:  $CLUSTER_NAME"
echo "==> Image:    $IMAGE"

# 1. Pega TD atual
CURRENT_TD=$(aws ecs describe-task-definition \
  --task-definition "$SERVICE" \
  --query 'taskDefinition' --output json)

# 2. Deriva nova TD trocando só a imagem do container alvo
NEW_TD=$(echo "$CURRENT_TD" | jq --arg img "$IMAGE" --arg cn "$CONTAINER_NAME" '
  .containerDefinitions |= map(if .name == $cn then .image = $img else . end) |
  del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
      .compatibilities, .registeredAt, .registeredBy)
')

# 3. Registra
NEW_ARN=$(echo "$NEW_TD" | aws ecs register-task-definition \
  --cli-input-json file:///dev/stdin \
  --query 'taskDefinition.taskDefinitionArn' --output text)
echo "==> New TD: $NEW_ARN"

# 4. Atualiza service
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE" \
  --task-definition "$NEW_ARN" \
  --query 'service.{name:serviceName,td:taskDefinition,desired:desiredCount,running:runningCount}' \
  --output table

echo "==> Update enviado. Aguardando estabilização (até 5min)…"
aws ecs wait services-stable --cluster "$CLUSTER_NAME" --services "$SERVICE"
echo "==> Service $SERVICE estável."
