# Models

Converted ONNX models used by `MediaPipeORTProvider` (ARCHITECTURE §10.1). Stored with Git LFS.

Do not add or edit files here by hand. Run `uv run scripts/models/fetch_and_convert.py` (added in P1.T2), which downloads the pinned MediaPipe sources, converts them, and rewrites `checksums.sha256`. `ModelLoader` refuses to load any model whose SHA-256 doesn't match (G-SEC-08).
