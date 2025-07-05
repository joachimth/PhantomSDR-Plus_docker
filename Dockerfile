# === Build Stage 1: Setting up PhantomSDR-Plus and necessary tools ===
#FROM python:3.10-slim-buster as builder

LABEL maintainer="Joachim Thirsbro <joachim@thirsbro.dk>"

# Set working directory
WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    meson \
    libfftw3-dev \
    libwebsocketpp-dev \
    libflac++-dev \
    zlib1g-dev \
    libzstd-dev \
    libboost-all-dev \
    libopus-dev \
    libliquid-dev \
    git \
    psmisc \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Clone and build PhantomSDR-Plus
RUN git clone https://github.com/joachimth/PhantomSDR-Plus_docker.git && \
    cd PhantomSDR-Plus \
    chmod +x *.sh \
    # sudo ./install.sh \
    rtl_sdr -f 145000000 -s 3200000 - | ./build/spectrumserver --config config.toml

# Define volume for logs
VOLUME /app/logs

# Expose port for Server Port
EXPOSE 9002

# Copy built binaries from builder stage
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/

# Copy application code
COPY . /app

# Define default command
CMD ["start-rtl.sh"]

# Metadata
LABEL \
    org.label-schema.name="pptf" \
    org.label-schema.description="Docker container for PhantomSDR-Plus" \
    org.label-schema.version="${DOCKER_IMAGE_VERSION:-}" \
    org.label-schema.vcs-url="https://github.com/joachimth/PhantomSDR-Plus" \
    org.label-schema.schema-version="1.0"
