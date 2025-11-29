#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
NC='\033[0m'

ENV_DIR="environments/development"

echo -e "${YELLOW}Getting values from Terraform...${NC}"

pushd "$ENV_DIR" >/dev/null

USER_POOL_ID=$(tofu output -raw cognito_user_pool_id)
CLIENT_ID=$(tofu output -raw cognito_web_client_id)
PORTAL_URL=$(tofu output -raw portal_url)

popd >/dev/null

# Validaciones básicas
if [[ -z "$USER_POOL_ID" || -z "$CLIENT_ID" || -z "$PORTAL_URL" ]]; then
  echo "ERROR: Missing required values:"
  echo "  USER_POOL_ID = '$USER_POOL_ID'"
  echo "  CLIENT_ID    = '$CLIENT_ID'"
  echo "  PORTAL_URL   = '$PORTAL_URL'"
  echo "Revisa que los outputs de Terraform existan y vuelve a intentar."
  exit 1
fi

# A partir del portal_url construimos las URLs para Cognito
CALLBACK_URL="${PORTAL_URL%/}/callback"   # quita / final si lo hubiera y añade /callback
LOGOUT_URL="${PORTAL_URL%/}"

export USER_POOL_ID CLIENT_ID CALLBACK_URL LOGOUT_URL

echo "UserPoolId : $USER_POOL_ID"
echo "ClientId   : $CLIENT_ID"
echo "Callback   : $CALLBACK_URL"
echo "Logout     : $LOGOUT_URL"
echo ""

# Build new URL lists (manteniendo localhost para dev)
NEW_CALLBACKS=()
NEW_LOGOUTS=()

# Añadimos siempre las URLs del portal (CloudFront)
NEW_CALLBACKS+=("$CALLBACK_URL")
NEW_LOGOUTS+=("$LOGOUT_URL")

# Añadimos localhost para desarrollo
NEW_CALLBACKS+=("http://localhost:3000/callback" "http://localhost:5000/callback")
NEW_LOGOUTS+=("http://localhost:3000" "http://localhost:5000")

echo -e "${YELLOW}New configuration to apply:${NC}"
echo "New Callback URLs:"
for url in "${NEW_CALLBACKS[@]}"; do
  echo "  - $url"
done

echo "New Logout URLs:"
for url in "${NEW_LOGOUTS[@]}"; do
  echo "  - $url"
done
echo ""

read -p "Do you want to update the Cognito client? (yes/no): " -r
echo

if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Update cancelled"
    exit 0
fi

echo -e "${YELLOW}Updating Cognito client...${NC}"

aws cognito-idp update-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$CLIENT_ID" \
  --callback-urls "${NEW_CALLBACKS[@]}" \
  --logout-urls "${NEW_LOGOUTS[@]}" \
  --allowed-o-auth-flows "code" "implicit" \
  --allowed-o-auth-scopes "email" "openid" "profile" \
  --allowed-o-auth-flows-user-pool-client \
  --supported-identity-providers "COGNITO" \
  > /dev/null

echo "Done."
