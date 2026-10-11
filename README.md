# swam-os-kinoite-amd

Image **bootc** (Fedora Atomic) basée sur **Kinoite officiel**
(`quay.io/fedora-ostree-desktops/kinoite:44`), construite avec
[BlueBuild](https://blue-build.org/).

Variante **GPU AMD** : elle embarque la pile **AMD ROCm**. Elle ne contient **ni pilotes NVIDIA, ni
modules MediaTek MT7927, ni modules manettes** — c'est la variante minimale côté GPU.

- **Base** : `quay.io/fedora-ostree-desktops/kinoite` version `44`
- **Image publiée** : `ghcr.io/swam-web/swam-os-kinoite-amd:latest`
- **Dépôt** : https://github.com/Swam-web/swam-os-kinoite-amd

## Personnalisations (tout est fait au build)

| | Détail |
|---|---|
| **Kernel** | CachyOS `kernel-cachyos-lto` (Clang LTO) — COPR `bieszczaders/kernel-cachyos-lto`, remplace le kernel Fedora (pattern `install-kernel-akmods` : shims des scriptlets `kernel-install`, `rpm --erase --nodeps`, versionlock). |
| **AMD ROCm (minimal gaming)** | dépôt officiel AMD `repo.radeon.com/rocm/rhel9/latest/main/` — Fedora n'étant pas une cible officielle, ce sont les paquets **RHEL 9** qui sont utilisés. Pile **minimale gaming** : `rocm-core`, `rocm-opencl-runtime`, `rocm-smi`. **Sans la pile HIP** (`rocm-hip-runtime`, `rocm-hip-libraries`, `rocm-libs`/rocBLAS ≈ 5-6 Go) : inutile aux jeux (Vulkan/DXVK via mesa) — qui en a besoin : `rpm-ostree install rocm-hip-runtime rocm-libs`. **Aucun dkms** : `amdgpu` est le pilote in-tree du kernel (CachyOS compris) ; le dépôt AMD ne propose qu'`amdgpu-dkms`, inutilisable sur bootc. `OpenCL-ICD-Loader` (fourni par la base) est remplacé par `ocl-icd`, requis par `rocm-opencl`. Le dépôt AMD **reste activé** sur l'image finale (mises à jour ROCm). |
| **Addons CachyOS** | `cachyos-settings`, `scx-scheds`, `scx-tools`, `scx-manager`, `ananicy-cpp`, `cachyos-ananicy-rules`. |
| **Impression / scan / découverte / firewall** | `cups`, `hplip`, `avahi`, `firewalld` (+ `firewall-config`, `firewall-applet`, `tmux`). Services `cups`, `avahi-daemon`, `firewalld`, `podman.socket` activés. |
| **fido2** | module `fido2` ajouté à l'initramfs (déverrouillage LUKS par clé FIDO2). |
| **DisplayLink** | **conservé tel que la base le fournit** — rien n'est retiré. |

## ⚠️ Caveats

- **Secure Boot** : le kernel CachyOS est signé par une clé qui n'est pas approuvée par Microsoft.
  Désactiver Secure Boot, ou enrôler votre propre clé MOK.
- Les **kmods de la base** compilés pour le kernel stock sont retirés (ils ne peuvent pas se
  charger sur le kernel CachyOS) ; `v4l2loopback` est fourni par le kernel CachyOS lui-même.
- Le kernel CachyOS est **clang/LTO** : tout kmod tiers devrait être recompilé pour cette ABI
  exacte (cette variante n'en embarque aucun).
- La base est un **tag flottant Fedora 44** (pas de digest épinglé) : le kernel officiel est de
  toute façon remplacé par celui de CachyOS, et Plasma/les composants suivent les mises à jour
  Fedora.

### ROCm et `/opt` — le point sensible

Dans l'image de base, `/opt` est un **lien vers `/var/opt` dont la cible n'existe pas** au moment
du build (`/var` est peuplé au runtime). Les RPM `rocm-*` écrivent dans `/opt/rocm-<version>` et
échouaient donc exactement ainsi :

```
[RPM] failed to open dir opt of /opt/: cpio: mkdir failed - File exists
[RPM] unpacking of archive failed on file /opt/rocm-7.2.4: cpio: mkdir failed - No such file or directory
Transaction failed: Rpm transaction failed.
```

D'où, **au début de `files/scripts/rocm.sh`** :

```bash
rm -f /opt && mkdir -p /opt
```

→ `/opt` devient un **vrai répertoire** (dans le root, donc suivi par bootc) : c'est la condition
pour que le gestionnaire de paquets puisse y écrire. Même cas que google-chrome ou docker-desktop,
documenté par le template Universal Blue.

Le script se termine par un **contrôle** : le build échoue si `rocminfo` ou `/opt/rocm*` manque,
plutôt que de livrer une image sans ROCm.

### Vérifier que ROCm est installé

Dans le système installé :

```bash
ls -ld /opt/rocm*                    # ROCm 7 s'installe dans /opt/rocm-<version>
/usr/bin/rpm -q rocm-core rocm-opencl-runtime rocm-smi
command -v rocminfo rocm-smi         # outils du runtime
rocminfo | head -30                  # LE test qui tranche : agents HSA + device AMD
clinfo -l                            # doit lister une plateforme AMD « ROCm »
```

Si `/opt` est **encore un lien** (`ls -ld /opt` → `/opt -> var/opt`) et que `/opt/rocm*` n'existe
pas, l'image installée est antérieure au correctif ci-dessus.

## Structure du dépôt (BlueBuild)

```
recipes/recipe.yml                       # recette principale
recipes/base/packages.yml                # addons CachyOS, paquets, services
files/scripts/kernel-cachyos.sh          # COPRs + kernel CachyOS clang-LTO
files/scripts/rocm.sh                    # AMD ROCm (dépôt, correctif /opt, pile userland)
files/scripts/cleanup.sh                 # nettoyage toolchain / repos de build
files/system/.../99-fido2.conf           # fido2 dans l'initramfs
disk_config/*.toml                       # config bootc-image-builder (ISO / qcow2)
.github/workflows/build.yml              # build + signature de l'image (GHCR)
.github/workflows/build-disk.yml         # build des images disque (bootc-image-builder)
```

> **Important** : chaque module `script` de BlueBuild s'exécute dans un **shell neuf**. Les
> variables partagées dans un `build.sh` monolithique (typiquement `KERNEL_VERSION`) doivent donc
> être **redéfinies dans chaque script** — sinon `set -u` fait échouer le build.

## Build en local

```bash
# image conteneur
sudo -E nix run github:blue-build/cli -- build recipe recipes/recipe.yml
```

Validation de la recette seule (rapide, sans build) :

```bash
bluebuild validate recipes/recipe.yml
```

## Images disque (ISO / qcow2)

`disk_config/iso.toml` bascule l'installation sur cette image à la fin :

```
bootc switch --mutate-in-place --transport registry ghcr.io/swam-web/swam-os-kinoite-amd:latest
```

> ## ⚠️ Construisez l'ISO avec `bootc-image-builder`, PAS avec `bluebuild generate-iso`
>
> `bluebuild generate-iso` fabrique son installateur **lorax** et prend par défaut
> `--variant kinoite` (source BlueBuild : `default_value = "kinoite"`). L'environnement
> d'installation porte alors `VARIANT_ID=kinoite`, Anaconda sélectionne le profil
> `fedora-kinoite`, qui hérite de `fedora-kde` :
>
> ```ini
> [User Interface]
> hidden_spokes =
>     NetworkSpoke
>     PasswordSpoke
>     UserSpoke
> ```
>
> **Conséquence** : les écrans « Création de l'utilisateur » et « Mot de passe root » sont
> masqués ; l'installation se termine **sans aucun compte** et l'on reste bloqué sur SDDM.
>
> `bootc-image-builder` produit un installateur dont l'`os-release` **n'a pas de `VARIANT_ID`** →
> le profil `fedora` générique s'applique, sans `hidden_spokes` : l'écran de création
> d'utilisateur est présent.
>
> **Le plus simple, et c'est déjà dans le dépôt** : `Actions → Build disk images → Run workflow`
> (`osbuild/bootc-image-builder-action`). C'est exactement l'outil qu'il faut.

## Installation

```bash
sudo bootc switch ghcr.io/swam-web/swam-os-kinoite-amd:latest
sudo systemctl reboot
```

## Signature

Les images sont signées avec **cosign** (clé publique dans `cosign.pub`). La clé privée doit être
dans le secret GitHub **`SIGNING_SECRET`** (clé **non protégée** : `COSIGN_PASSWORD="" cosign
generate-key-pair`). Le module BlueBuild `signing` installe les politiques de vérification pour
`rpm-ostree`/`bootc`.

```bash
cosign verify --key cosign.pub ghcr.io/swam-web/swam-os-kinoite-amd:latest
```

## Crédits

[Fedora Kinoite](https://fedoraproject.org/kinoite/) / [Universal Blue](https://universal-blue.org/),
[BlueBuild](https://blue-build.org/), [CachyOS](https://cachyos.org/) kernel & addons,
[AMD ROCm](https://rocm.docs.amd.com/).
