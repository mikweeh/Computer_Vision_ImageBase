FROM mikweeh/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04@sha256:61a4aafb0094cd773f11eefa378929d5a687bd775febeb78eac62fc824141fb5

ARG UID=1000
ARG GID=1000

# Keep Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1
# Turn off buffering for easier container logging
ENV PYTHONUNBUFFERED=1
ENV WORKSPACE=/home/rosuser/repo_out

# Fix locale configuration
RUN apt-get update && apt-get install -y locales && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen en_US.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set locale environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    LANGUAGE=en_US:en

# Working directory
WORKDIR ${WORKSPACE}

# Install system dependencies
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/London
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglib2.0-0 \
    libtcl8.6 libtk8.6 tk \
    python3-tk \
    git \
    x11-apps \
    xauth \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install pip requirements (PyTorch already installed)
COPY ./requirements.txt ./
RUN pip install --ignore-installed --no-cache-dir -r requirements.txt

# Copy source code
COPY ./src ./src

# Create user (adapted from your working setup)
RUN if getent group $GID >/dev/null; then \
    existing_group=$(getent group $GID | cut -d: -f1); \
    useradd -m -u $UID -g $existing_group -s /bin/bash rosuser; \
else \
    groupadd -g $GID rosuser && \
    useradd -m -u $UID -g $GID -s /bin/bash rosuser; \
fi

# Set ownership and permissions
RUN chown -R $UID:$GID /home/rosuser

# Pre-create mount point directories with correct ownership
# These directories serve as mount targets for derived projects' docker-compose volumes.
# The base docker-compose.yml only mounts dataset; repo_out and catkin_ws/src/repo_ros
# are mounted by derived projects (e.g., Docker_ROSnoetic_python3.11, Marine_postprocessing).
# - repo_out/: py311/CV project code (primary workspace, already set via WORKSPACE env)
# - catkin_ws/src/repo_ros/: ROS code (read-only cross-mount from ROS container)
# - dataset/: shared data (mounted by base and derived compose files)
RUN mkdir -p /home/rosuser/repo_out \
             /home/rosuser/catkin_ws/src/repo_ros \
             /home/rosuser/dataset \
    && chown -R $UID:$GID /home/rosuser/repo_out \
                          /home/rosuser/catkin_ws \
                          /home/rosuser/dataset

# Switch to non-root user
USER rosuser

# Install Jupyter kernel for the user (critical for VSCode/JupyterLab)
RUN python -m ipykernel install --user --name=python3 --display-name="Python 3"

CMD ["python", "src/main.py"]

# docker compose build --no-cache
# docker compose exec dev_service xeyes
# docker compose exec dev_service python -c "import torch;print(f'PyTorch version: {torch.__version__}');print(f'CUDA available: {torch.cuda.is_available()}')"
