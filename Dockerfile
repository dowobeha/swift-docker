# ==========================================
# 1. HARVESTER: Extracts only essential binaries
# ==========================================
# We use the full 'noble' image to grab the tools we need
FROM swift:noble as harvester
WORKDIR /staging
RUN mkdir -p bin lib/swift

# A. Copy Core Toolchain (Compiler + Runtime)
RUN cp -P /usr/bin/swift* /staging/bin/
RUN cp -r /usr/lib/swift /staging/lib

# B. Copy SourceKit-LSP (REQUIRED for VS Code Autocomplete)
RUN cp -P /usr/bin/sourcekit-lsp /staging/bin/

# C. Clean up heavy items we don't need in cloud/grading
# (Removes LLDB, Docs, Package Manager caches to save ~500MB)
RUN rm -f /staging/bin/lldb* \
          /staging/bin/swift-lldb* \
          /staging/bin/docc* \
          /staging/bin/swift-help*

# ==========================================
# 2. TARGET: GRADER (For PrairieLearn)
# ==========================================
FROM swift:noble-slim as grader

# Runtime dependencies for swiftc
RUN apt-get update && apt-get install -y \
    libsqlite3-0 libxml2 libz1 git \
    && rm -rf /var/lib/apt/lists/*

# Copy Toolchain (No SourceKit needed here - PL is text only)
COPY --from=harvester /staging/bin/swift* /usr/bin/
COPY --from=harvester /staging/lib/ /usr/lib/swift/

# [FUTURE PLACEHOLDER] This is where we will COPY your uaf-grader later
# COPY --from=builder /usr/local/bin/uaf-grader /usr/local/bin/

RUN mkdir -p /grade/student /grade/tests /grade/results
WORKDIR /grade

# ==========================================
# 3. TARGET: DEV (For VS Code / GitHub Classroom)
# ==========================================
FROM swift:noble-slim as dev

# Install interactive tools students need
RUN apt-get update && apt-get install -y \
    curl git unzip vim nano \
    libsqlite3-0 libxml2 libz1 \
    && rm -rf /var/lib/apt/lists/*

# Copy Toolchain (+ SourceKit for Autocomplete)
COPY --from=harvester /staging/bin/ /usr/bin/
COPY --from=harvester /staging/lib/ /usr/lib/swift/

# --- USER SETUP (VS Code Friendly) ---
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# 1. Ensure the group exists
RUN groupadd --gid $USER_GID --non-unique $USERNAME || true

# 2. Create the user (Using your --non-unique trick)
RUN useradd --non-unique --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 3. Fix Ownership for SourceKit/Swift folders
RUN chown -R $USER_UID:$USER_GID /usr/lib/swift

USER $USERNAME
WORKDIR /home/$USERNAME

# Verify install
RUN swift --version