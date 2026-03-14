# hazel

A Kubernetes `k3d` and `Helm` development environment and deployment tool for hazel.sh.

> [!WARNING]
> 2025-10-04

## Founding concepts

## Features

### Dev features
- hot reloading for all relevant projects
- Automated TLS locally (and on the server)
- Interaction with the sites using only port 443, whether pointing to a host-local, hot-reloaded dev version or not
- and the Deploy features

### Deploy features
- Automated S3-compatible (point-in-time) db, (point-in-time) storage backups included
- Bootstrap/disaster recovery from S3-compatible storage

## Dev/operator workstation prerequisites

This setup has been tested on Ubuntu 24.04 and should work seamlessly on similar setups. It should also work well on recent (2025+) WSL2-Ubuntu 24.04 setups (with a couple of extra 1-2 minute setup steps). It probably works on recent MacOS, though hasn't been tested.

First make sure you have `docker` properly installed:

- `docker` - [Official instructions](https://docs.docker.com/engine/install/ubuntu/)

Then, install `mise`:

```bash
curl https://mise.run | sh
```

Then install the rest:

```bash
mise use --global bun@latest k3d@latest kubectl@latest helm@latest helmfile@latest argo@latest
```

A full local setup including all servers (DBs, electric, etc.) will require 2GB+ of RAM and a reasonably recent/powerful processor (laptop 2020+, desktop 2018+).

You also _need_ ports `80` and `443` free and usable when running `hazel` and, if you want easy, direct access to the servers (dbs, redis, etc.) then ports 30432-30437 (these can also be changed within Kuberentes "nodeport range" but require modifying the scripts) should also be free.

## Installation

### Components

While you can (obviously!) choose to use external services, the default install will install [Kubernetes Operators](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/) for:

- Garage (garage-operator)
- Postgres (CNPG)
- Redis (Opstree)

And (normal) Helm-based installs for the following:

- Cert-manager
- Argo Workflows
- Traefik
- Coredns

## Dev deployment

> [!NOTE]
> All commands after the clone should be executed from the directory that contains the `vars.sh.default` file (should be the same as this `README`)

Init your workstation setup:

```bash
git clone git@github.com:HazelChat/hazel.git && cd kube
# or https://github.com/HazelChat/hazel.git
cp --update vars.sh.default vars.sh && touch kube/k3d-deploy/{overrides-local.yaml,overrides-infra-local.yaml}
```

These files are NOT managed by git and are included in the various scripts to store environment variables and values overrides for the two main helm charts.

If your personalisation needs are more substantial, you could copy this repo's `kube` (root level dir) and adapt outside of this repo. Don't hesitate to submit PRs if you think others might benefit from your changes!

### Cluster init

```bash
bash kube/k3d-deploy/k3d-create-backups-cluster.sh && kube/k3d-deploy/k3d-create-cluster.sh && bash kube/k3d-deploy/create-secrets.sh
```

### Reinstall `hazel-infra`

> [!NOTE]
> The `k3d-cluster-install.sh` script above installs the hazel-infra chart, so the following is only necessary if you want to redeploy just `hazel-infra` for some reason.

```bash
bash kube/k3d-deploy/infra-install.sh
```

### Install hazel

```bash
bash kube/k3d-deploy/install.sh
```

### Init hazel dbs/resources

```bash
bash kube/k3d-deploy/init.sh
```

Show init progress:

```bash
source vars.sh && argo logs -f @latest
```

### Launch realtime backups baselines

> [!NOTE]
> Requires the `cnpg` kubectl plugin, see below:

```bash
source vars.sh
kubectl cnpg backup db-cluster --method plugin --plugin-name barman-cloud.cloudnative-pg.io
```

Alternatively, the default settings launch nightly backups - the next one will serve as the first baseline if you don't launch these now.

## Dev development

Unless you change the default settings, if you set `hazel.isDev: true`:


```yaml
# e.g, in overrides-local.yaml
hazel:
  isDev: true
```

Then the system has been set up to load project files from `apps`.

```bash
# from `kube/k3d-deploy/k3d-create-cluster.sh`
k3d cluster create ${APPNAME} --config ${SCRIPT_DIR}/k3d-config.yml \
...
  --volume ${SCRIPT_DIR}/volumes:/opt/${APPNAME}/volumes@all \
  --volume ${SCRIPT_DIR}/../../apps:/apps@all
```

If you have other special needs then you should probably just copy this repo's `kube` directory somewhere and make changes as you see fit. It is all standard `k3d` and/or `helm` (with a couple of useful helper scripts) - nothing more, so Google, Stackoverflow, Reddit and your usual help haunts are your friends!

## Staging/Prod deployment

If you are not comfortable with Helm (or at least want to be), you should probably stick with docker compose.

> [!WARNING]
> The default dev secrets (in `kube/k3d-deploy/secrets/hazel*`) *ARE NOT SUITABLE FOR PRODUCTION*. They are all basically some variant of "password". This is great for dev but not great for prod. The YAML secret files contain annotations which allow them to be reliably regenerated using basically identical code to Tutor via the python script `kube/k8s-deploy/regen-secrets.py`. Basically you just run that script (which needs either python's `pycryptodome` to be available to python, or linux's command line `openssl` to be available to the CL) with the `kube/k3d-deploy/secrets` directory as the first parameter and an output directory as the second and then you will have 3 directories you *CAN* `kubectl apply -f ...` to production, then properly manage with your secrets-management system.

### Recommended extras

#### kubectl cnpg plugin

```bash
CNPG_VERSION="1.28.1"
wget https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v${CNPG_VERSION}/kubectl-cnpg_${CNPG_VERSION}_linux_x86_64.deb
sudo apt install ./kubectl-cnpg_${CNPG_VERSION}_linux_x86_64.deb
rm kubectl-cnpg_${CNPG_VERSION}_linux_x86_64.deb
```

# TODOs
- integrate a proper secrets manager (SOPS?) for gitops
- integrate CI/CD
  - Argo?
  - add a registry (harbor? zot? maybe move to full oci when ImageVolumes goes GA?)
