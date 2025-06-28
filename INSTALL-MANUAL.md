# Manual instructions

If you don't want to use terraform, the following manual steps replace steps 6 & 7 in [INSTALL.md](INSTALL.md).

## Cloudflare setup

### Tunnel

Go to Zero Trust in the Cloudflare dashboard, Networks, Tunnels. Create a tunnel, choose a name, then select the docker option. Copy the command and extract the token, and create a secret with name `tunnel` in namespace `cloudflared` using a key of `token`.

In the cloudflare dashboard for your domain, add a DNS entry for a CNAME proxied entry for `*.yourdomain.com` to `<your tunnel id>.cfargotunnel.com`.

### Application

Go to Zero Trust in the Cloudflare dashboard, Access. From Overview, add an IDP - choose github and follow the instructions.

In policies create two:
* Name: `Interactive`, Action: `Allow`, Rule: allow by email (add email associated with your github account)
* Name: `Non interactive`, Action: `Service auth`, Rule: any access service token, valid certificate

In Applications, create a new application: self-hosted, name `Kubernetes apps`, public hostname, subdomain `*`, domain `yourdomain.com`, select both `Interactive` and `Non interactive` policies, disable "Accept all identity providers", enable only github auth, then enable "Instant auth". Accept defaults on following pages.

### Local access

You may want to enable local access to some apps, bypassing Cloudflare (including authentication). Some mobile apps (e.g. Immich) support multiple URLs in order of preference, or using certain URLs when connected to a specific WiFi network. However we still want to secure the traffic with TLS, by configuring cert-manager to issue a certificate for Traefik to use.

Create a DNS entry for `local` and `*.local` in Cloudflare DNS, with an A record containing the private IP of your server.

For cert-manager to handle the challenge, it needs a Cloudflare token to modify DNS settings. Follow just 2 steps from [this guide](https://blog.stonegarden.dev/articles/2023/12/traefik-wildcard-certificates/#dns-provider-cloudflare) to create a Cloudflare token and add it to a Kubernetes secret in `kube-system` (do not keep following the instructions to create an `Issuer` etc)

## GitHub setup

You'll need to create a (private) repo for your gitops repo from the [template repo](https://github.com/laurence404/gitops-template). Generate a SSH key locally using `ssh-keygen -f id_rsa_github`, add the public key as an access key to the repo on github, then connect to the repo in ArgoCD and paste in the private key.

## Setup ArgoCD

Add the ApplicationSet using kubectl or Headlamp:
```
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: gitops
  namespace: argocd
spec:
  generators:
    - git:
        directories:
          - path: '*'
        repoURL: git@github.com:your_username/your_gitops.git
        revision: HEAD
  goTemplate: true
  goTemplateOptions:
    - missingkey=error
  ignoreApplicationDifferences:
    - jsonPointers:
        - /spec/syncPolicy
  syncPolicy:
    preserveResourcesOnDeletion: true
  template:
    metadata:
      annotations:
        argocd.argoproj.io/manifest-generate-paths: .
      name: '{{.path.basename}}'
    spec:
      destination:
        namespace: '{{.path.basename}}'
        server: https://kubernetes.default.svc
      project: default
      source:
        helm:
          values: |
            domain: yourdomain.com
            aud: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
            teamName: yourteamname
        path: '{{.path.path}}'
        repoURL: git@github.com:your_username/your_gitops.git
        targetRevision: HEAD
      syncPolicy:
        automated: {}
        managedNamespaceMetadata:
          labels:
            pod-security.kubernetes.io/enforce: privileged
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```
Replace `your_username/your_gitops.git`, `yourdomain.com`, `aud` tag (see "Kubernetes apps" Cloudflare Zero Trust application) and `yourteamname` from step 5. You can also change the default [pod security standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/) on namespaces created by ArgoCD for your apps.

### Enable ArgoCD webhooks

To avoid waiting for up to 3 minutes for ArgoCD to notice changes in your gitops repo, you'll need to enable webhooks. However GitHub can't send webhooks to ArgoCD as it's protected by Zero Trust Access policies.

Add a new policy:
* Name: `Everyone`, Action: `Service auth`, Rule: Everyone

Add 2 new Applications:
* self-hosted, name `ArgoCD Webhook`, public hostname, subdomain `argocd`, domain `yourdomain.com`, path `/api/webhook`, select `Everyone` policy. Accept defaults on following pages.
* self-hosted, name `ArgoCD ApplicationSet Webhook`, public hostname, subdomain `argocd-applicationset`, domain `yourdomain.com`, path `/api/webhook`, select `Everyone` policy. Accept defaults on following pages.

To ensure webhooks only come from github, use a worker to validate the webhook secret. In the Cloudflare dashboard, go to Compute (Workers) and create a "hello world" worker. Then edit the code and paste in [github-webhook.js](tf/modules/cloudflare/github-webhook.js) and click Deploy. Go to settings and add a variable of type secret, name: `WEBHOOK_SECRET` and set value to a random password. Then add two routes for `argocd.yourdomain.com/api/webhook` and `argocd-applicationset.yourdomain.com/api/webhook`.

Lastly add both webhook URLs with the secret to your gitops repo on github, with content type `application/json` and just push events.