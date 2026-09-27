export VAULT_ADDR="http://127.0.0.1:8200";
export VAULT_TOKEN="..."; #рут токен

vault auth disable jwt

# 2. Включаем заново
vault auth enable jwt

vault secrets enable -path=pki_int pki
vault secrets tune -max-lease-ttl=8760h pki_int

# 3. Настраиваем конфиг заново (с нужными параметрами)
vault write auth/jwt/config \
  jwks_url="http://10.130.0.13:4646/.well-known/jwks.json" \
  jwt_supported_algs="RS256,EdDSA" \
  bound_issuer="nomad" \
  default_role="nginx-backend" \
  disable_bound_issuer_validation=true

# 4. Пересоздаём роль
vault write auth/jwt/role/nginx-backend \
  role_type="jwt" \
  bound_audiences="vault.io" \
  user_claim="/nomad_job_id" \
  user_claim_json_pointer=true \
  token_policies="nginx-policy, vault-cert-policy" \
  token_period="30m"

vault write auth/jwt/role/nginx-frontend \
  role_type="jwt" \
  bound_audiences="vault.io" \
  user_claim="/nomad_job_id" \
  user_claim_json_pointer=true \
  token_policies="nginx-policy, vault-cert-policy" \
  token_period="30m"

vault write pki_int/root/generate/internal \
  common_name="Nomad Test Root CA" \
  ttl=8760h

vault write pki_int/roles/nomad-role \
  allowed_domains="global.nomad" \
  allow_subdomains=true \
  max_ttl="72h"


