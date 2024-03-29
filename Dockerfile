FROM ubuntu:23.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG PODMAN_PACKAGE=podman_4.4.0+ds1-1_${TARGETARCH}.deb
ARG TARGETARCH
ARG NVM_VERSION=0.39.5

RUN mkdir -p /etc/apt/keyrings

RUN apt-get update && \
	apt-get install -y ca-certificates curl gnupg

# Debian Testing/Bookworm
RUN curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:unstable/Debian_Testing/Release.key \
  | gpg --dearmor \
  | tee /etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg > /dev/null
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_unstable.gpg]\
    https://download.opensuse.org/repositories/devel:kubic:libcontainers:unstable/Debian_Testing/ /" \
  | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:unstable.list > /dev/null


RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y  jq unzip \
    buildah skopeo podman libgpgme11 libyajl2 conmon fuse-overlayfs \
    slirp4netns make binfmt-support qemu-user-static qemu-system-arm git && \
#    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    if [ "${TARGETARCH}" = "arm64" ]; \
	then export ARCH_ENV=aarch64; \
	else export ARCH_ENV=x86_64; \
	fi && \
	curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_ENV}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    aws --version && \
    apt remove -y unzip && \
    rm -rf /var/lib/apt/lists/* ./aws awscliv2.zip

RUN useradd podman; \
echo podman:10000:5000 > /etc/subuid; \
echo podman:10000:5000 > /etc/subgid;

VOLUME /var/lib/containers
VOLUME /home/podman/.local/share/containers

ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/libpod/master/contrib/podmanimage/stable/podman-containers.conf /home/podman/.config/containers/containers.conf
COPY ./config/storage.conf /etc/containers/storage.conf

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf; \
 sed -i -e 's|^#mount_program|mount_program|g' -e '/additionalimage.*/a "/var/lib/shared",' -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' -e 's|oracle|podman|g' /etc/containers/storage.conf;
RUN mkdir -p /var/lib/shared/overlay-images /var/lib/shared/overlay-layers /var/lib/shared/vfs-images /var/lib/shared/vfs-layers; touch /var/lib/shared/overlay-images/images.lock; touch /var/lib/shared/overlay-layers/layers.lock; touch /var/lib/shared/vfs-images/images.lock; touch /var/lib/shared/vfs-layers/layers.lock

RUN mkdir -p /home/podman/.local/share/containers/storage /home/podman/images

RUN chown podman:podman -R /home/podman

ENV _CONTAINERS_USERNS_CONFIGURED=""

ENV NODE_VERSION=18.17.1
ENV NVM_DIR=/home/podman/.nvm

RUN mkdir /home/podman/.nvm && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash && \
	. "$NVM_DIR/nvm.sh" && nvm install ${NODE_VERSION} && \
	. "$NVM_DIR/nvm.sh" && nvm use v${NODE_VERSION} && \
	. "$NVM_DIR/nvm.sh" && nvm alias default v${NODE_VERSION} && \
    npm install -g semantic-release @semantic-release/exec @semantic-release/commit-analyzer @semantic-release/release-notes-generator @semantic-release/changelog @semantic-release/github  @semantic-release/git npm@latest

ENV PATH="${NVM_DIR}/versions/node/v${NODE_VERSION}/bin/:${PATH}"

WORKDIR /home/podman
