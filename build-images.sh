#!/bin/bash

# Terminate on error
set -e

# Prepare variables for later use
images=()
# The image will be pushed to GitHub container registry
repobase="ghcr.io/nethesis"

# Configure the image name
reponame="nethvoice-proxy-postgres"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/postgres
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-kamailio"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/kamailio
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-redis"
# Build and commit the image
buildah bud -t "${repobase}/${reponame}" modules/redis
# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Configure the image name
reponame="nethvoice-proxy-rtpengine"
buildah bud -t "${repobase}/${reponame}" modules/rtpengine
# Append the image URL to the images array
images+=("${repobase}/${reponame}")


# Configure the image name
reponame="nethvoice-proxy"
# Create a new empty container image
container=$(buildah from scratch)

# Reuse existing nodebuilder-kickstart container, to speed up builds
if ! buildah containers --format "{{.ContainerName}}" | grep -q nodebuilder-nethvoice-proxy; then
    echo "Pulling NodeJS runtime..."
    buildah from --name nodebuilder-nethvoice-proxy -v "${PWD}:/usr/src:Z" docker.io/library/node:lts
fi

echo "Build static UI files with node..."
buildah run \
    --workingdir=/usr/src/ui \
    --env="NODE_OPTIONS=--openssl-legacy-provider" \
    nodebuilder-nethvoice-proxy \
    sh -c "yarn install && yarn build"

# Add imageroot directory to the container image
buildah add "${container}" imageroot /imageroot
buildah add "${container}" ui/dist /ui
# Setup the entrypoint, ask to reserve one TCP port with the label and set a rootless container
buildah config --entrypoint=/ \
    --label="org.nethserver.rootfull=0" \
    --label="org.nethserver.images=docker.io/jmalloc/echo-server:latest873a4eb4b18f44f7e08c9ee463cee1e48029728a" \
    --label="org.nethserver.images=${repobase}/nethvoice-proxy-postgres:${IMAGETAG:-latest} \
    ${repobase}/nethvoice-proxy-kamailio:${IMAGETAG:-latest} \
    ${repobase}/nethvoice-proxy-redis:${IMAGETAG:-latest} \
    ${repobase}/nethvoice-proxy-rtpengine:${IMAGETAG:-latest}" \
    "${container}"
# Commit the image
buildah commit "${container}" "${repobase}/${reponame}"

# Append the image URL to the images array
images+=("${repobase}/${reponame}")

# Setup CI when pushing to Github.
# Warning! docker::// protocol expects lowercase letters (,,)
if [[ -n "${CI}" ]]; then
    # Set output value for Github Actions
    printf "::set-output name=images::%s\n" "${images[*]}"
else
    # Just print info for manual push
    printf "Publish the images with:\n\n"
    for image in "${images[@],,}"; do printf "  buildah push %s docker://%s:%s\n" "${image}" "${image}" "${IMAGETAG:-latest}" ; done
    printf "\n"
fi
