# === PhantomSDR-Plus Docker Container ===
FROM python:3.10-slim-buster

LABEL maintainer="Joachim Thirsbro <joachim@thirsbro.dk>"

# Set working directory
WORKDIR /app

# Install dependencies
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
    rtl-sdr \
    && rm -rf /var/lib/apt/lists/*

# Clone and build PhantomSDR-Plus
RUN git clone https://github.com/joachimth/PhantomSDR-Plus_docker.git && \
    cd PhantomSDR-Plus_docker && \
    chmod +x *.sh && \
    ./install.sh

# Copy application files if needed
COPY . /app/

# Create logs directory
RUN mkdir -p /app/logs

# Define volume for logs
VOLUME /app/logs

# Expose port for Server Port
EXPOSE 9002

# Set PATH to include local binaries
ENV PATH="/usr/local/bin:${PATH}"

# Ensure LD_LIBRARY_PATH includes local libraries
ENV LD_LIBRARY_PATH="/usr/local/lib:${LD_LIBRARY_PATH}"

# Define default command
CMD ["./start-rtl.sh"]

# Metadata labels
LABEL \
    org.label-schema.name="phantomsdr-plus" \
    org.label-schema.description="Docker container for PhantomSDR-Plus" \
    org.label-schema.version="${DOCKER_IMAGE_VERSION:-latest}" \
    org.label-schema.vcs-url="https://github.com/joachimth/PhantomSDR-Plus" \
    org.label-schema.schema-version="1.0"
