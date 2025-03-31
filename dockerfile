# Use an official Ubuntu base image
FROM ubuntu:22.04

# Set environment variables for non-interactive installs
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    python3-pip \
    r-base \
    && rm -rf /var/lib/apt/lists/*

# Install IQ-TREE
RUN wget https://github.com/iqtree/iqtree2/releases/download/v2.3.2/iqtree-2.3.2-Linux.tar.gz && \
    tar -xzf iqtree-2.3.2-Linux.tar.gz && \
    mv iqtree-2.3.2-Linux/iqtree2 /usr/local/bin/iqtree2 && \
    rm -rf iqtree-2.3.2-Linux*

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# Install R packages (including 'ape')
RUN R -e "install.packages('ape', repos='http://cran.r-project.org')"

# Create directories for scripts and data
WORKDIR /app
COPY scripts/ /scripts/
COPY data/ /data/
COPY config.yaml /config.yaml

# Set execution permissions
RUN chmod +x /scripts/assignement_merge.sh

# Define the default command
CMD ["/scripts/assignement_merge.sh"]
