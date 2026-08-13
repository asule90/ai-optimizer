# Debian image to simulate a fresh machine for setup.sh.
# Includes Node.js 22+ (QMD), Go 1.26.x, and build-essential. Omits RTK, ICM, pipx, and Python tooling.
# Pre-installs Cursor CLI (agent) via the official installer.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

ARG NODE_MAJOR=22
ARG GO_VERSION=1.26.5
ARG TARGETARCH

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    sudo \
    procps \
    tar \
    tini \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

RUN case "${TARGETARCH}" in \
      amd64|arm64) go_arch="${TARGETARCH}" ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
  && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${go_arch}.tar.gz" -o /tmp/go.tgz \
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm /tmp/go.tgz

ENV PATH="/usr/local/go/bin:${PATH}"

ARG USERNAME=testuser
ARG USER_UID=1000
ARG USER_GID=1000

ENV GOPATH="/home/${USERNAME}/go"
ENV PATH="${GOPATH}/bin:${PATH}"

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}" \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}" \
  && mkdir -p "${GOPATH}" \
  && chown -R "${USER_UID}:${USER_GID}" "${GOPATH}"

RUN su - "${USERNAME}" -c 'curl https://cursor.com/install -fsS | bash' \
  && mkdir -p /opt \
  && cp -a "/home/${USERNAME}/.local/share/cursor-agent" /opt/cursor-agent \
  && AGENT_BIN="$(find /opt/cursor-agent/versions -maxdepth 2 -type f -name cursor-agent | sort | tail -1)" \
  && test -n "${AGENT_BIN}" \
  && ln -sf "${AGENT_BIN}" /usr/local/bin/agent \
  && ln -sf "${AGENT_BIN}" /usr/local/bin/cursor-agent

# Cursor CLI also lives under ~/.local; bind-mounting ./docker/local hides that.
# Keep a copy under /opt + /usr/local/bin so `agent` survives re-runs.

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
