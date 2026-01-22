# ==========================================
# 1. HARVESTER: Extracts & Cleans
# ==========================================
FROM swift:noble as harvester
WORKDIR /staging

# Create directory structure
RUN mkdir -p usr/bin usr/lib/swift

# A. Copy Binaries
RUN cp -P /usr/bin/swift* usr/bin/
RUN cp -P /usr/bin/sourcekit-lsp usr/bin/

# B. Copy Runtime
RUN cp -r /usr/lib/swift/* usr/lib/swift/

# C. Copy Compiler Internal Libs (Preserving structure)
RUN cp -P /usr/lib/libSwift*.so usr/lib/ || true
RUN cp -P /usr/lib/lib_*.so usr/lib/ || true
RUN cp -P /usr/lib/libsourcekit*.so usr/lib/ || true
RUN cp -P /usr/lib/libdispatch*.so usr/lib/ || true
RUN cp -P /usr/lib/libBlocks*.so usr/lib/ || true

# --- THE DIET PLAN (Aggressive Cleaning) ---
# 1. Remove Static Libraries (The biggest savings)
#    (Students use dynamic linking, so these .a files are dead weight)
RUN find usr/lib -name "*.a" -type f -delete

# 2. Remove Documentation/Source Info (Not needed for compilation)
RUN find usr/lib -name "*.swiftdoc" -type f -delete
RUN find usr/lib -name "*.swiftsourceinfo" -type f -delete

# 3. Remove CMAKE configs (Not used in your class)
RUN find usr/lib -name "cmake" -type d -exec rm -rf {} +

# 4. Remove heavy binary tools
RUN rm -f usr/bin/lldb* \
          usr/bin/swift-lldb* \
          usr/bin/docc* \
          usr/bin/swift-help* \
          usr/bin/swift-package-collection*

# ==========================================
# 2. TARGET: GRADER (Ultra-Light)
# ==========================================
FROM swift:noble-slim as grader

# Added: binutils, libc6-dev (Required for the linker 'ld' to work)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 libxml2 libz1 git \
    libncurses6 libtinfo6 \
    libcurl4 ca-certificates \
    libpython3-stdlib \
    binutils libc6-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=harvester /staging/usr/ /usr/

RUN mkdir -p /grade/student /grade/tests /grade/results
WORKDIR /grade

# ==========================================
# 3. TARGET: DEV (Optimized VS Code)
# ==========================================
FROM swift:noble-slim as dev

# Added: binutils, libc6-dev (Required for the linker 'ld' to work)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip vim nano \
    libsqlite3-0 libxml2 libz1 \
    libncurses6 libtinfo6 \
    libcurl4 ca-certificates \
    libpython3-stdlib \
    binutils libc6-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=harvester /staging/usr/ /usr/

# --- USER SETUP ---
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu

RUN groupadd --gid $USER_GID $USERNAME
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

RUN chown -R $USER_UID:$USER_GID /usr/lib/swift

USER $USERNAME
WORKDIR /home/$USERNAME

RUN swift --version
