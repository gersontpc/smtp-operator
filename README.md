# SMTP Relay Container (Postfix + Gmail)

Este projeto fornece uma imagem de contêiner POSIX que roda **Postfix** como um relay SMTP. Ele aceita conexões sem autenticação (clientes dentro do cluster Kubernetes) e encaminha as mensagens usando uma conta Gmail configurada via variáveis de ambiente.

---

## Como funciona

1. O Pod expõe porta `25` e aceita e-mails de aplicações (clientes) sem autenticação.
2. Um `entrypoint.sh` configura dinamicamente o `main.cf` do Postfix com as credenciais do Gmail.
3. O Postfix autentica-se no servidor SMTP do Gmail (`smtp.gmail.com:587`) e encaminha as mensagens.

```mermaid
flowchart LR
    subgraph Cluster Kubernetes
        Client[Aplicação cliente\n(envia e-mail)] -->|porta 25\nsem autenticação| Pod[Pod smtp-relay]
        Pod -->|entrypoint.sh configura| Postfix[Postfix]
    end

    Postfix -->|SMTP/STARTTLS\nsmtp.gmail.com:587\n(RELAY_USER/RELAY_PASSWORD)| Gmail[(Servidor SMTP\ndo Gmail)]

    style Client fill:#f9f,stroke:#333,stroke-width:1px
    style Pod fill:#bbf,stroke:#333,stroke-width:1px
    style Postfix fill:#bfb,stroke:#333,stroke-width:1px
    style Gmail fill:#ffb,stroke:#333,stroke-width:1px

    %% notas
    note right of Pod
      - `entrypoint.sh` gera `main.cf` usando\nvariáveis de ambiente:\nRELAY_USER, RELAY_PASSWORD, MYDOMAIN
    end
```


## Variáveis de ambiente obrigatórias

| Variável | Descrição |
|----------|-----------|
| `RELAY_USER` | Conta Gmail completa (ex: user@gmail.com) |
| `RELAY_PASSWORD` | Senha ou App Password do Gmail |
| `MYDOMAIN` *(opcional)* | Nome de host que o Postfix anunciará |


## Como construir a imagem

```sh
cd smtp-relay
docker build -t myregistry/smtp-relay:latest .
```

Substitua `myregistry` pelo repositório de sua escolha.

## Uso em Kubernetes

1. **Crie um secret** com as credenciais do Gmail (substitua valores reais):

```sh
kubectl apply -f k8s/secret.yaml
```

2. **Deslize os recursos**:

```sh
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

> Se necessário ajuste o namespace ou o nome do secret.

Os pods clientes podem então enviar e-mail para `smtp-relay.default.svc.cluster.local:25` (ajuste o namespace conforme necessário).

Exemplo de envio de um pod cliente:

```sh
# dentro de outro pod
echo -e "Subject: teste\n\ncorpo" | sendmail -S smtp-relay.default.svc.cluster.local:25 destinatario@exemplo.com
```

> **Nota**: O Gmail exige que você use uma senha de aplicativo se 2FA estiver habilitado.

## Manifestos Kubernetes

Os arquivos YAML em `k8s/` descrevem:

- `ConfigMap` para armazenar configurações estáticas caso necessário
- `Deployment` que define réplicas do serviço de relay
- `Service` de tipo `ClusterIP` para expor porta 25

> Ajuste rótulos, namespaces e recursos de acordo com a sua infraestrutura.

---

Sinta‑se livre para adaptar conforme as políticas de segurança do seu cluster. Essa imagem **não** faz nenhuma validação do remetente ou do conteúdo; use-a exclusivamente em redes confiáveis ou adicione controles adicionais conforme necessário.

## Funcionamento do Operator

Quando usado como um operador Kubernetes, o controlador observa recursos customizados (por exemplo, `SMTPRelay`) e garante que a infraestrutura
esteja alinhada com a especificação desejada. O fluxo típico é:

```mermaid
flowchart LR
    subgraph Cluster
        CR[SMTPRelay Custom Resource]
        Operator[SMTP Operator]
        Deployment[Deployment \n+ Pod smtp-relay]
        Service[Service ClusterIP]
        Secret[Secret Gmail creds]
        Client[Cliente de aplicação]
    end

    CR -->|reconcile| Operator
    Operator -->|cria/atualiza| Deployment
    Operator --> Service
    Operator --> Secret
    Client -->|envia e-mail porta 25| Service
```

Esse diagrama mostra o loop de reconciliação e como o operador gera/atualiza os objetos Kubernetes necessários
(e adaptações similares podem ser aplicadas para outras configurações).


