# ----
FROM debian:bookworm
ARG GHVERSION="2.74.1"

# more stuff than we need.. clean this to get something more streamline...
RUN apt update && apt install -y iproute2 netcat-openbsd iputils-ping curl python3 pip tcpdump magic-wormhole procps wget net-tools npm nodejs

WORKDIR /root

# Get gh client.
RUN wget https://github.com/cli/cli/releases/download/v${GHVERSION}/gh_${GHVERSION}_linux_amd64.tar.gz
RUN tar -xzf gh_${GHVERSION}_linux_amd64.tar.gz
RUN cp gh_${GHVERSION}_linux_amd64/bin/gh /usr/bin

COPY scripts/* /root

# Get python and node anthropic and openai support
RUN pip install anthropic --break-system-packages
RUN npm install @anthropic-ai/sdk
RUN pip install openai --break-system-packages
RUN npm install openai

COPY startup.sh /usr/local/bin
CMD ["startup.sh"]
