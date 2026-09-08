# Official immich-server plus an ffmpeg shim that injects format=nv12 into
# VAAPI encode commands coming from the software-decode fallback path,
# working around immich-app/immich#27895 (AMD Mesa rejects yuv420p surfaces).
# Keep the base tag in sync with the workflow tag suffix.
FROM ghcr.io/immich-app/immich-server:v3.1.0

COPY ffmpeg /usr/local/bin/ffmpeg
RUN chmod 755 /usr/local/bin/ffmpeg
