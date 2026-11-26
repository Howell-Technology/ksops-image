# ksops-image

An **unofficial rebuild** of [KSOPS](https://github.com/viaduct-ai/kustomize-sops)
(viaduct-ai/kustomize-sops) v4.5.1, published as `ghcr.io/howell-technology/ksops`.
Howell Technology maintains it for its own Argo CD clusters. It is the upstream
v4.5.1 code, rebuilt with current Go and patched Go dependencies.

> **Not affiliated with Viaduct.** The image may be removed once upstream
> ships a release with fixed dependencies. If you use it, pin it by digest and
> watch upstream.

## Why this exists

KSOPS v4.5.1 (April 2026) is the latest upstream release, and nothing has been
merged upstream since. Its binary is built with Go 1.25.0 and older libraries
that have known vulnerabilities. That includes a critical one in
`golang.org/x/crypto` (CVE-2026-46595) and several in `x/net`, `x/text`,
`grpc` and the Go standard library. In Argo CD, the ksops binary runs in the
repo-server next to the SOPS key that decrypts every secret, so it should not
carry known holes.

Upstream's Dependabot PRs ([#341](https://github.com/viaduct-ai/kustomize-sops/pull/341),
[#339](https://github.com/viaduct-ai/kustomize-sops/pull/339)) have been open
since July 2026 and only cover part of this.

## What changed from upstream v4.5.1

No ksops source code is changed. Only the build inputs are:

| | Upstream v4.5.1 | This rebuild |
|---|---|---|
| Go toolchain | 1.25.0 | 1.26.11 |
| `golang.org/x/crypto` | 0.48.0 | 0.59.0 |
| `golang.org/x/net` | 0.50.0 | 0.63.0 |
| `golang.org/x/text` | 0.34.0 | 0.44.0 |
| `google.golang.org/grpc` | 1.79.3 | 1.85.0 |
| `go.opentelemetry.io/otel` | 1.45.0 | 1.47.0 |
| `go.mongodb.org/mongo-driver` | 1.13.1 | 1.17.7 |
| `github.com/getsops/sops/v3` | 3.12.2 | **3.12.2 (unchanged, on purpose)** |
| govulncheck | 12+ reachable vulnerabilities | none |

**Why sops stays on 3.12.2:** sops 3.13 changed how YAML comments are
handled, and 3.13.2 shipped a bug that broke the integrity check (MAC) when
decrypting lists that contain comments. That bug was fixed in 3.13.3. This
rebuild exists only to close vulnerabilities, so it does not change how
secrets are decrypted. Dependabot is told to skip sops minor versions.

### Files changed (Apache-2.0 §4(b) notice)

- `go.mod`, `go.sum`: the dependency versions above.
- `Dockerfile`: replaced. The upstream one is kept as `Dockerfile.upstream`.
  The image now contains only the ksops binary, on `gcr.io/distroless/static:nonroot`.
  It has no kustomize, git or shell. Every base image is pinned by digest.
- `.github/`: upstream's release, CodeQL and Go workflows are removed, and
  replaced with `build.yml` and a new Dependabot config.
- `README.md`: this file. The upstream README is kept as `README-upstream.md`.

## Image

```
ghcr.io/howell-technology/ksops:<tag>@sha256:<digest>
```

- **Platforms:** `linux/amd64`, `linux/arm64`.
- **Tags:**
  - `v4.5.1-ht.N`: releases. `N` goes up with each rebuild of the same upstream version.
  - `main`, `sha-<short>`: builds from `main`.
- **Binary:** `/usr/local/bin/ksops`, the same path as upstream (also `kustomize-sops`).
- **Supply chain:** each image carries an SBOM and SLSA provenance, generated
  by `docker/build-push-action`.

**Always pin by digest.** Tags are only labels.

### Argo CD repo-server (exec plugin via `ksops install`)

This is a drop-in replacement for `viaductoss/ksops:v4.5.1` in the usual
init-container pattern:

```yaml
repoServer:
  volumes:
    - name: ksops-install
      emptyDir: {}
  volumeMounts:
    - name: ksops-install
      mountPath: /etc/kustomize/plugin/viaduct.ai/v1/ksops/ksops
      subPath: ksops
  initContainers:
    - name: install-ksops
      image: ghcr.io/howell-technology/ksops:v4.5.1-ht.1@sha256:<digest>
      command: ["/usr/local/bin/ksops", "install", "/ksops-install"]
      volumeMounts:
        - name: ksops-install
          mountPath: /ksops-install
```

## Build and CI

`.github/workflows/build.yml` runs on every push and pull request:

1. **test:** installs upstream's pinned kustomize, builds ksops into a
   kustomize plugin home (the same layout as Argo CD), then runs upstream's
   full test suite. It then runs `govulncheck`, and any reachable
   vulnerability fails the build.
2. **image:** only on `main`, `v*` tags or a manual run, never on a pull
   request. Builds the multi-arch image and pushes it to GHCR.

Building locally:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t ksops:dev .
# or just the binary
CGO_ENABLED=0 go build -trimpath -o ksops .
```

### Security model

This repository is public, but whoever can push here can ship code that runs
next to a SOPS key. So:

- **GitHub-hosted runners only.** Never self-hosted ones, because a pull request
  from a fork would run its code on them.
- **`pull_request`, never `pull_request_target`.** Fork pull requests get a
  read-only token and no secrets. Workflows from outside contributors need
  approval before they run.
- **Images are pushed only from `main` and from tags.** `main` is protected.
- **Every action is pinned to a commit SHA** and every base image to a digest.
  Dependabot proposes updates as pull requests.
- **Consumers pin by digest.** A pushed tag changes nothing in a cluster
  until someone reviews and changes the pin.

## Updating

- **Dependency or base-image bump:** merge the Dependabot pull request once CI
  passes, then tag `v4.5.1-ht.<N+1>`. CI publishes the image, and the
  digest shows in the run summary. Then update the digest pin where the image
  is used.
- **New upstream release:** if upstream ships a release with current
  dependencies, switch back to the official `viaductoss/ksops` image and
  archive this repo. Otherwise, merge the new upstream tag into `main`,
  reapply the dependency updates, and tag `v<upstream>-ht.1`.

## License

KSOPS is licensed under the Apache License 2.0 (see `LICENSE`), and so is this
rebuild. Copyright in the KSOPS source belongs to its upstream authors.
