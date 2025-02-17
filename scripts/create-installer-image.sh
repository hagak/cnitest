#!/bin/sh

EXTENSIONS=(
  # NOTE: ghcr.io/nberlee/rk3588 is added automatically to this extension list!
  # Images for Storage classes:
  "ghcr.io/siderolabs/iscsi-tools:v0.1.4"
)

if ! type docker &> /dev/null; then
  echo "*** docker must be installed! Install 'docker': https://www.docker.com/products/docker-desktop/ ***"
  exit 1
fi

if ! type crane &> /dev/null; then
  echo "*** crane must be installed! Install 'crane': https://github.com/google/go-containerregistry/blob/main/cmd/crane/README.md ***"
  exit 1
fi

if ! type talosctl &> /dev/null; then
  echo "*** talosctl must be installed! Install 'talosctl': https://github.com/siderolabs/homebrew-tap ***"
  exit 1
fi

if ! type jq &> /dev/null; then
  echo "*** jq must be installed! Install 'jq': https://jqlang.github.io/jq/download/ ***"
  exit 1
fi

echo "Determining Talos version..."
TALOS_VERSION=$(talosctl version --client | grep "Tag:" | awk '{print $2}')
#TALOS_VERSION=v1.7.6
echo "Talos client version ${TALOS_VERSION} found. We will use that version for the Talos nodes, too."

EXTENSIONS_IMAGE=ghcr.io/hagak/turingpi-image/installer:${TALOS_VERSION}

echo $CR_PAT | docker login ghcr.io -u hagak --password-stdin

echo "Creating Talos image $EXTENSIONS_IMAGE with provided extensions..."
sudo docker run --rm -t \
       -v $PWD/_out:/out \
       ghcr.io/nberlee/imager:${TALOS_VERSION} installer \
       --arch arm64 \
       --platform metal \
       --overlay-name turingrk1 \
       --overlay-image ghcr.io/nberlee/sbc-turingrk1:${TALOS_VERSION} \
       --base-installer-image ghcr.io/nberlee/installer:${TALOS_VERSION}-rk3588 \
       --system-extension-image ghcr.io/nberlee/rk3588:${TALOS_VERSION}@$(crane digest ghcr.io/nberlee/rk3588:${TALOS_VERSION} --platform linux/arm64) \
       $(for extension in "${EXTENSIONS[@]}"; do printf " --system-extension-image $extension@$(crane digest $extension --platform linux/arm64) "; done)

if [ ! -f _out/installer-arm64.tar ]; then
  echo "*** Installer expected to be created by the Imager (previous step), but it is not! Exiting. ***"
  exit 1
fi

crane push _out/installer-arm64.tar $EXTENSIONS_IMAGE
