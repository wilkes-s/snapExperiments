# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.231.6/containers/ubuntu/.devcontainer/base.Dockerfile

# [Choice] Ubuntu version (use hirsuite or bionic on local arm64/Apple Silicon): hirsute, focal, bionic
ARG VARIANT="hirsute"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}


RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && apt-get -y upgrade 

RUN apt-get -y install build-essential gcc-arm-linux-gnueabihf gcc-arm-linux-gnueabi 

RUN apt-get -y install make bison flex libssl-dev tree bc lzop