FROM debian:testing-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install APT packages
RUN apt-get update && export \
    && apt-get -y install --no-install-recommends \
    tar curl zip unzip bash-completion build-essential ripgrep htop \
    ninja-build ccache g++ mold gdb clang-format clang-tidy \
    rpm pkg-config cmake git gettext libsdl2-dev libsdl2-image-dev libsodium-dev \
    libpng-dev libbz2-dev libgtest-dev libgmock-dev libbenchmark-dev zsh \
    qtbase5-dev qt6-base-dev ristretto ca-certificates procps sudo

# Install devilutionx-graphics-tools
RUN git clone https://github.com/diasurgical/devilutionx-graphics-tools.git /tmp/devilutionx-graphics-tools && \
    cd /tmp/devilutionx-graphics-tools && \
    cmake -S. -Bbuild-rel -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF && \
    cmake --build build-rel -j $(getconf _NPROCESSORS_ONLN) && \
    cmake --install build-rel --component Binaries && \
    rm -rf /tmp/devilutionx-graphics-tools

# Install devilutionx-mpq-tools
RUN git clone https://github.com/diasurgical/devilutionx-mpq-tools.git /tmp/devilutionx-mpq-tools && \
    cd /tmp/devilutionx-mpq-tools && \
    cmake -S. -Bbuild-rel -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF && \
    cmake --build build-rel -j $(getconf _NPROCESSORS_ONLN) && \
    cmake --install build-rel && \
    rm -rf /tmp/devilutionx-mpq-tools

# Install d1-graphics-tool
RUN git clone https://github.com/diasurgical/d1-graphics-tool.git /tmp/d1-graphics-tool && \
    cd /tmp/d1-graphics-tool && \
    cmake -S. -Bbuild-rel -G Ninja -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build-rel -j $(getconf _NPROCESSORS_ONLN) && \
    cmake --install build-rel && \
    rm -rf /tmp/d1-graphics-tool

# Download spawn.mpq and fonts.mpq
RUN curl --create-dirs -O -L --output-dir /usr/local/share/diasurgical/devilutionx/ \
    https://github.com/diasurgical/devilutionx-assets/releases/latest/download/spawn.mpq && \
    curl --create-dirs -O -L --output-dir /usr/local/share/diasurgical/devilutionx/ \
    https://github.com/diasurgical/devilutionx-assets/releases/latest/download/fonts.mpq && \
    chmod -R a+Xr /usr/local/share/diasurgical/

# Install smpq
RUN --mount=type=bind,source=tools/build_and_install_smpq.sh,target=/tmp/build_and_install_smpq.sh sh /tmp/build_and_install_smpq.sh

RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Create a non-root user with passwordless sudo
RUN useradd -m -s /bin/bash -u 1000 developer \
    && echo "developer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/developer \
    && chmod 0440 /etc/sudoers.d/developer

# Switch to developer user and configure PATH
USER developer
ENV HOME=/home/developer
ENV PATH="/home/developer/.local/bin:${PATH}"

# Install Claude CLI in user space
RUN curl -fsSL https://claude.ai/install.sh | bash

WORKDIR /workspace

CMD ["/bin/bash"]
