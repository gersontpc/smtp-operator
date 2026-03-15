## Build da imagem

O código-fonte da imagem está em `smtp-app/`.

```sh
docker build -t myregistry/smtp-relay:latest smtp-app
```

Substitua `myregistry` pelo registry desejado.

## Execução local

```sh
docker run --rm -p 25:25 \
  -e RELAY_USER=you@gmail.com \
  -e RELAY_PASSWORD="sua-app-password" \
  -e MYDOMAIN="smtp-relay.default.svc.cluster.local" \
  myregistry/smtp-relay:latest
```