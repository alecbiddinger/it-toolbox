FROM ubuntu:24.04

ARG TOOLBOX_VERSION=1.0.0
LABEL org.opencontainers.image.title="IT Troubleshooting Toolbox" \
      org.opencontainers.image.description="Disposable network diagnostics and Python tools for home labs." \
      org.opencontainers.image.version="${TOOLBOX_VERSION}" \
      org.opencontainers.image.licenses="MIT"

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dnsutils \
        iproute2 \
        iputils-ping \
        jq \
        netcat-openbsd \
        nmap \
        openssl \
        python3 \
        python3-pip \
        python3-venv \
        tcpdump \
        traceroute \
        tree \
        whois \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY LICENSE /usr/share/doc/it-toolbox/LICENSE
COPY scripts/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/*.sh
WORKDIR /work
CMD ["/bin/bash"]
