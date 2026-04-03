#!/bin/bash
set -e

# Configuration
PROJECT_ID="imrenagicom"
SA_NAME="codelabs"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
GITHUB_REPO="imrenagicom/codelabs"

echo "1. Creating Service Account: ${SA_NAME}..."
gcloud iam service-accounts create "${SA_NAME}" \
  --project="${PROJECT_ID}" \
  --display-name="Codelabs Deploy SA" || echo "Service account may already exist"

echo "Waiting for service account to propagate across Google Cloud..."
sleep 10

echo "2. Granting Roles to ${SA_EMAIL}..."
ROLES=(
  "roles/run.admin"
  "roles/iam.serviceAccountUser"
  "roles/cloudbuild.builds.editor"
  "roles/storage.admin"
  "roles/artifactregistry.admin"
)

for role in "${ROLES[@]}"; do
  echo " - Granting ${role}..."
  # Retry loop in case IAM propagation takes a bit longer
  n=0
  until [ $n -ge 5 ]; do
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="serviceAccount:${SA_EMAIL}" \
      --role="${role}" \
      --condition=None > /dev/null && break
    n=$((n+1))
    echo "Retrying..."
    sleep 5
  done
done

echo "3. Creating Workload Identity Pool 'github'..."
gcloud iam workload-identity-pools create "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" || echo "Pool may already exist"

echo "4. Creating Workload Identity Provider 'github-provider'..."
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'imrenagicom'" \
  --issuer-uri="https://token.actions.githubusercontent.com" || echo "Provider may already exist"

echo "5. Binding GitHub repository ${GITHUB_REPO} to Service Account..."
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github/attribute.repository/${GITHUB_REPO}" > /dev/null

echo ""
echo "========================================="
echo "SETUP COMPLETE!"
echo "========================================="
echo "WIF_SERVICE_ACCOUNT="
echo "${SA_EMAIL}"
echo ""
echo "WIF_PROVIDER="
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)"
echo "========================================="
