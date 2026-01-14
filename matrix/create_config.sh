docker run -it --rm \
    -v "$(pwd)/synapse_data:/data" \
    -e SYNAPSE_SERVER_NAME=example.com \
    -e SYNAPSE_REPORT_STATS=yes \
    matrixdotorg/synapse:latest generate
