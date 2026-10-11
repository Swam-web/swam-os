#!/usr/bin/env bash

# AMD ROCm : depot officiel + pile userland
## Fedora n'est pas une cible officielle d'AMD : ce sont les paquets RHEL 9
## qui sont utilises. Les depots AMD restent actives sur l'image finale pour
## que ROCm recoive les mises a jour.
## Aucun dkms : amdgpu est le pilote in-tree, fourni par le kernel (CachyOS
## compris) — le depot AMD ne propose qu'amdgpu-dkms, inutilisable sur bootc.
set -ouex pipefail

### Depot officiel AMD (ROCm)
cat > /etc/yum.repos.d/rocm.repo <<'EOF'
[rocm]
name=AMD ROCm
baseurl=https://repo.radeon.com/rocm/rhel9/latest/main/
enabled=1
gpgcheck=1
gpgkey=https://repo.radeon.com/rocm/rocm.gpg.key
enabled_metadata=1
metadata_expire=6h
type=rpm-md
repo_gpgcheck=0
EOF

### /opt : sans ca, les RPM rocm-* ne peuvent pas s'installer
## Dans l'image de base, /opt est un lien vers /var/opt dont la cible n'existe
## pas au moment du build (/var est peuple au runtime). RPM tente alors :
##   mkdir /opt              -> cpio: mkdir failed - File exists
##                              (le lien est deja la)
##   mkdir /opt/rocm-<ver>   -> cpio: mkdir failed - No such file or directory
##                              (la cible du lien ne resout pas)
## et toute la transaction echoue :
##   Unpack error: rocm-hip-libraries-... / Transaction failed: Rpm transaction failed.
## On remplace le lien par un vrai repertoire : c'est la condition pour que le
## gestionnaire de paquets puisse ecrire dans /opt (meme cas que google-chrome
## ou docker-desktop, documente par le template Universal Blue).
rm -f /opt && mkdir -p /opt

### ocl-icd : requis par rocm-opencl, a la place d'OpenCL-ICD-Loader
## L'ICD loader fourni par la base entre en conflit avec le Provide ocl-icd
## attendu par rocm-opencl. On l'echange (|| true : absent = rien a faire).
dnf5 -y remove OpenCL-ICD-Loader || true
## --refresh : métadonnées en cache vs versions retirées des miroirs
## (cf. dépôt kinoite-nvidia)
dnf5 -y --refresh install ocl-icd

### Pile ROCm — MINIMALE pour le gaming
## HIP (rocm-hip-runtime, rocm-libs/rocBLAS…) = calcul GPU / IA (~5-6 Go),
## inutile aux jeux : ils passent par Vulkan/DXVK (mesa). Qui en a besoin :
##   rpm-ostree install rocm-hip-runtime rocm-libs
dnf5 -y install \
    rocm-core \
    rocm-opencl-runtime \
    rocm-smi

### Verification : on echoue ici plutot que de livrer une image sans ROCm
command -v rocm-smi >/dev/null 2>&1 || {
    echo "ERREUR : rocm-smi absent — la pile ROCm n'a pas ete installee"
    exit 1
}
ls -d /opt/rocm* >/dev/null 2>&1 || {
    echo "ERREUR : /opt/rocm* absent — les RPM rocm-* ne se sont pas installes"
    exit 1
}
echo "ROCm (minimal gaming) installe : $(ls -d /opt/rocm* | head -1)"
