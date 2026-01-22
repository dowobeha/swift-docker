# ==========================================
# 1. HARVESTER: Extracts binaries AND structure
# ==========================================
FROM swift:noble as harvester
WORKDIR /staging

# Create the exact directory structure we need to preserve
RUN mkdir -p usr/bin usr/lib/swift

# A. Copy Binaries to /staging/usr/bin
RUN cp -P /usr/bin/swift* usr/bin/
RUN cp -P /usr/bin/sourcekit-lsp usr/bin/

# B. Copy Swift Runtime (The 'swift' folder) to /staging/usr/lib/swift
RUN cp -r /usr/lib/swift/* usr/lib/swift/

# C. Copy Compiler Internal Libs (THE FIX)
# These live in /usr/lib/ in the base image, not inside /usr/lib/swift/
# We copy them to /staging/usr/lib/ so the compiler can find them at runtime.
RUN cp -P /usr/lib/libSwift*.so usr/lib/ || true
RUN cp -P /usr/lib/lib_*.so usr/lib/ || true
RUN cp -P /usr/lib/libsourcekit*.so usr/lib/ || true
RUN cp -P /usr/lib/libdispatch*.so usr/lib/ || true
RUN cp -P /usr/lib/libBlocks*.so usr/lib/ || true

# D. Clean up bloat
RUN rm -f usr/bin/lldb* \
          usr/bin/swift-lldb* \
          usr/bin/docc* \
          usr/bin/swift-help*

# ==========================================
# 2. TARGET: GRADER (For PrairieLearn)
# ==========================================
FROM swift:noble-slim as grader

# Runtime dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-0 libxml2 libz1 git \
    libncurses6 libtinfo6 \
    libcurl4 ca-certificates \
    libpython3-stdlib \
    && rm -rf /var/lib/apt/lists/*

# COPY THE WHOLE TREE (The Fix)
# Instead of copying bin and lib separately, we overlay the /usr tree.
# This ensures libs end up in /usr/lib and /usr/lib/swift exactly where expected.
COPY --from=harvester /staging/usr/ /usr/

RUN mkdir -p /grade/student /grade/tests /grade/results
WORKDIR /grade

# ==========================================
# 3. TARGET: DEV (For VS Code / GitHub Classroom)
# ==========================================
FROM swift:noble-slim as dev

# Install interactive tools
RUN apt-get update && apt-get install -y \
    curl git unzip vim nano \
    libsqlite3-0 libxml2 libz1 \
    libncurses6 libtinfo6 \
    libcurl4 ca-certificates \
    libpython3-stdlib \
    && rm -rf /var/lib/apt/lists/*

# COPY THE WHOLE TREE (The Fix)
COPY --from=harvester /staging/usr/ /usr/

# --- USER SETUP ---
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# 1. Handle UID 1000 Conflict
RUN touch /var/mail/ubuntu && chown ubuntu /var/mail/ubuntu && userdel -r ubuntu

# 2. Create User
RUN groupadd --gid $USER_GID $USERNAME
RUN useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 3. Fix Ownership
RUN chown -R $USER_UID:$USER_GID /usr/lib/swift

USER $USERNAME
WORKDIR /home/$USERNAME

RUN swift --version
