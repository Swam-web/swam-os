# swam-os-bazzite

Image **bootc** (Fedora Atomic) basée sur [**Bazzite**](https://bazzite.gg/), construite avec
[BlueBuild](https://blue-build.org/). C'est la déclinaison *bazzite* de
[`swam-os-kinoite`](https://github.com/Swam-web/swam-os-kinoite) : mêmes personnalisations,
socle différent (Bazzite = Kinoite + couche gaming).

- **Base** : `ghcr.io/ublue-os/bazzite:stable`
- **Image publiée** : `ghcr.io/swam-web/swam-os-bazzite:latest`

## Personnalisations (tout est fait au build)

| | Détail |
|---|---|
| **Kernel** | CachyOS `kernel-cachyos-lto` (Clang LTO) — COPR `bieszczaders/kernel-cachyos-lto`, remplace le kernel Fedora (pattern `install-kernel-akmods` de Bazzite : shims des scriptlets `kernel-install`, `rpm --erase --nodeps`, versionlock). |
| **NVIDIA open** | dépôt [negativo17](https://negativo17.org/) : `akmod-nvidia` (userland + modules) avec les kmods recompilés **avec clang contre le kernel CachyOS**. |
| **MediaTek MT7927 / MT6639** | modules WiFi + Bluetooth out-of-tree patchés ([`jetm/mediatek-mt7927-dkms`](https://github.com/jetm/mediatek-mt7927-dkms), version épinglée), précompilés contre le kernel CachyOS, + le blob firmware BT que `linux-firmware` ne fournit pas encore. |
| **Manettes Xbox** | `xone` (dongle USB) et `xpadneo` (Bluetooth), compilés contre le kernel CachyOS. |
| **Addons CachyOS** | `cachyos-settings`, `scx-manager`, `ananicy-cpp`, `cachyos-ananicy-rules` (`scx-scheds`/`scx-tools` sont déjà dans la base). |
| **Impression / scan / découverte / firewall** | `cups`, `hplip`, `avahi`, `firewalld` — services activés. |
| **fido2** | module `fido2` ajouté à l'initramfs (déverrouillage LUKS par clé FIDO2). |

## Installation

```bash
sudo bootc switch ghcr.io/swam-web/swam-os-bazzite:latest
sudo systemctl reboot
```

Pour un ISO d'installation : voir la section « Images disque » plus bas.

## ⚠️ Caveats

- **Secure Boot** : le kernel CachyOS et les modules construits ne sont pas signés par une clé
  approuvée par Microsoft. Désactiver Secure Boot, ou enrôler votre propre clé MOK.
- Le driver **NVIDIA open** supporte **Turing (RTX 20) et plus récent**.
- Les **kmods de la base** compilés pour le kernel stock sont supprimés (ils ne peuvent pas se
  charger sur le kernel CachyOS) ; `v4l2loopback` est fourni par le kernel CachyOS lui-même.
- Le build **MT7927** télécharge une tarball `kernel.org` et un ZIP driver depuis le CDN ASUS
  **au moment du build**.
- **La base est volontairement NON épinglée par digest** (`ghcr.io/ublue-os/bazzite:stable`).
  L'ancien dépôt était épinglé par un bot (renovate) sur le build du **2 sept. 2026**, qui
  embarquait **KWin 6.7.4** : une régression du compositeur cassait l'affichage dans les **VM à
  graphisme non accéléré** (`virtio-gpu`) — `Failed to find a working output layer
  configuration` → **écran noir après le logo**. Corrigé dans **Plasma 6.7.5** (8 sept. 2026).
  Le tag flottant suit les mises à jour Fedora 44 ; le pinning docker de renovate est désactivé
  pour les fichiers `Containerfile`. **Si vous réintroduisez un digest, vérifiez
  `kwin_wayland --version` ≥ 6.7.5.**

## Structure du dépôt (BlueBuild)

```
recipes/recipe.yml                      # recette principale (9 modules)
recipes/base/packages.yml               # addons CachyOS, paquets, services
files/scripts/kernel-cachyos.sh         # COPRs + kernel CachyOS clang-LTO
files/scripts/nvidia.sh                 # negativo17 open + kmods rpmbuild clang
files/scripts/mt7927.sh                 # MediaTek MT7927 / MT6639
files/scripts/xone-xpadneo.sh           # manettes Xbox (xone + xpadneo)
files/scripts/cleanup.sh                # nettoyage toolchain / repos de build
files/system/.../99-fido2.conf          # fido2 dans l'initramfs
disk_config/*.toml                      # config bootc-image-builder (ISO / qcow2)
.github/workflows/build.yml             # build + signature de l'image (GHCR)
.github/workflows/build-disk.yml        # build des images disque (bootc-image-builder)
```

> **Important** : chaque module `script` de BlueBuild s'exécute dans un **shell neuf**. Les
> variables partagées dans l'ancien `build.sh` monolithique (typiquement `KERNEL_VERSION`)
> doivent donc être **redéfinies dans chaque script** — sinon `set -u` fait échouer le build.

## Build en local

```bash
cd swam-os-bazzite-bluebuild

# image + ISO en une commande
sudo -E nix run github:blue-build/cli -- generate-iso \
  --iso-name swam-os-bazzite.iso recipe recipes/recipe.yml

# ou juste l'image conteneur (pour tester sans l'ISO)
sudo -E nix run github:blue-build/cli -- build recipe recipes/recipe.yml
```

Validation de la recette seule (rapide, sans build) :

```bash
bluebuild validate recipes/recipe.yml
```

## Images disque (ISO / qcow2)

`disk_config/iso.toml` fait, à la fin de l'installation, un
`bootc switch … ghcr.io/swam-web/swam-os-bazzite:latest` pour basculer sur cette image.

```bash
sudo -E nix run github:blue-build/cli -- generate-iso \
  --iso-name swam-os-bazzite.iso recipe recipes/recipe.yml
```

Ou via GitHub Actions : `Actions → Build disk images → Run workflow`
(l'artefact ISO/qcow2 est ensuite disponible dans le résumé du job, ou sur S3 si configuré).

## Signature

Les images sont signées avec **cosign** (clé publique dans `cosign.pub`). La clé privée doit être
dans le secret GitHub **`SIGNING_SECRET`** (clé **non protégée** : `COSIGN_PASSWORD="" cosign
generate-key-pair`). Le module BlueBuild `signing` installe les politiques de vérification pour
`rpm-ostree`/`bootc`.

Vérification :

```bash
cosign verify --key cosign.pub ghcr.io/swam-web/swam-os-bazzite:latest
```

## Images sœurs

- [`swam-os-kinoite`](https://github.com/Swam-web/swam-os-kinoite) — même personnalisations sur
  Fedora Kinoite officiel.

## Crédits

Bazzite / [Universal Blue](https://universal-blue.org/), [BlueBuild](https://blue-build.org/),
[CachyOS](https://cachyos.org/) kernel & addons, [negativo17](https://negativo17.org/),
[jetm/mediatek-mt7927-dkms](https://github.com/jetm/mediatek-mt7927-dkms),
[dlundqvist/xone](https://github.com/dlundqvist/xone),
[atar-axis/xpadneo](https://github.com/atar-axis/xpadneo).
