## Integracion con Cloudflare Pages

Primero cree el proyecto:

```bash
npx wrangler pages project create fak-docs --production-branch=main
```
Esto crea un proyecto de tipo Direct Upload, o sea, que espera que le uplodeen los cambios

En https://dash.cloudflare.com/profile/api-tokens, cree un token llamado fak-docs-CI con las siguientes caracteristicas:

- Permissions: Account
- Cloudflare Pages
- Edit

Con ese token , hice esto para crear los secrets que Github Actions necesita:

```bash
gh secret set CLOUDFLARE_API_TOKEN

# Y a este le puse 5ecd8a7880ec9a8fc2bd6fbebd751893
gh secret set CLOUDFLARE_ACCOUNT_ID
```

Y luego con esto cree el DNS

```bash
export CLOUDFLARE_API_TOKEN=valor_aca

curl -X POST "https://api.cloudflare.com/client/v4/accounts/5ecd8a7880ec9a8fc2bd6fbebd751893/pages/projects/fak-docs/domains" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"name": "fak-docs.krapp.dev"}'
```

Y con esto lo verifique

```bash
curl -s "https://api.cloudflare.com/client/v4/accounts/5ecd8a7880ec9a8fc2bd6fbebd751893/pages/projects/fak-docs/domains" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | jq
```
