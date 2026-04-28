# demokb-products-app

Aplicação Node.js de exemplo para POC de pipeline multi-ambiente (dev/qa/prod).

Branches:
- `dev`  → trigger do CodePipeline (build + deploy ECS dev)
- `qa`   → criada/atualizada pelo pipeline após aprovação manual
- `main` → recebe PR automático; ao merjar, GitHub Action gera release e dispara pipeline prod
