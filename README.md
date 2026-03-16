This system is a dockerized base image for computer vision applications.

## The environment inside

It uses a python 3.11 with cuda 12.4 support. The libraries installed and versions are:
```
torch==2.8.0+cu128
albumentations==2.0.8
debugpy==1.8.17
flake8==7.3.0
hydra-core==1.3.2
imutils==0.5.4
matplotlib==3.10.6
numpy==2.2.6
opencv-python==4.12.0.88
pandas==2.3.2
pillow==11.3.0
pycocotools==2.0.10
pytest==8.4.2
reportlab==4.4.4
scikit-learn==1.7.2
scipy==1.16.2
shap==0.48.0
shapely==2.1.2
streamlit==1.50.0
tensorboard==2.20.0
tqdm==4.67.1
transformers==4.56.2
ultralytics==8.3.203
wandb==0.22.0
```

## What do I need to use it?

You have to have at least cuda 12.4 to run it, and of course docker installed
with the possibility of using GPU.

## Architecture

This is a base image. All project code is COPYed into the image at build time — no
host directory is bind-mounted for code. The working directory inside the container
is `/home/rosuser/repo_out`.

The following directories are pre-created inside the image as mount targets for
derived projects:

- `/home/rosuser/repo_out` — output workspace; derived projects mount their build artifacts here
- `/home/rosuser/catkin_ws/src/repo_ros` — ROS package source mount point
- `/home/rosuser/dataset` — dataset mount point

Derived projects' `docker-compose.yml` files bind-mount into these locations as needed.

## Environment Variables

Configure the `.env` file (use `dotenv.template` as a starting point) with the following variables:

- `PROJECT_NAME`: Project name that determines the container name.
- `DATASET_PATH`: Path where the dataset is stored on the host (e.g., `/home/haddo/Datasets`). It is mounted at `/home/rosuser/dataset` inside the container as a read/write bind mount, so that any changes you make are also reflected in the original folder outside the container.
- `CONTAINER_DISPLAY`: Value of the DISPLAY variable to export images
  - With AnyDesk or local: usually `:1` (or `:0`)
  - With SSH: Use the host IP address with the port you prefer from 15 to 50 (e.g., `172.XX.XX.XX:30`, example choosing port 30). Remember this choice.

You can also add variables `GID` and `UID` if you want.

## Using the Development Environment

To start the environment:
```
$ docker compose up -d
```

This creates the container. The dataset is available at `/home/rosuser/dataset` inside
the container. You can debug code step by step with VSCode.

To stop the environment:
```
$ docker compose down -v
```

When the system is stopped, the container is removed.

## Testing

A test script is provided at `tests/test_installation.sh`. Run it to verify that the
image builds correctly and that GPU access and key libraries are working:
```
$ bash tests/test_installation.sh
```

You can also check manually from outside the container:
```
# Check graphical forwarding
docker compose exec dev_service xeyes

# Check GPU
docker compose exec dev_service python -c "import torch;print(f'PyTorch version: {torch.__version__}');print(f'CUDA available: {torch.cuda.is_available()}')"
```
