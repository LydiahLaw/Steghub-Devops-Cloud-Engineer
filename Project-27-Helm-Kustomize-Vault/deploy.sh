#!/usr/bin/env bash
# Usage: ./deploy.sh <app|vault> <dev|sit|prod|local>
# Renders a Kustomize overlay and replaces the AWS_ACCOUNT_ID placeholder.
set -euo pipefail
cd "$(dirname "$0")"

COMPONENT="${1:?app or vault}"
ENV="${2:?dev, sit, prod or local}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"

case "$COMPONENT" in
  app)   DIR="tooling-app-kustomize/overlays/$ENV"; HELM="" ;;
  vault) DIR="vault/overlays/$ENV"; HELM="--enable-helm" ;;
  *)     echo "Unknown component: $COMPONENT"; exit 1 ;;
esac

kubectl kustomize $HELM "$DIR" | sed "s/AWS_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" | kubectl apply -f -
