# CosmogAI Swift library + Drive notebook

`CosmogAI` is a small Swift package with fast file access rooted in a mounted Google Drive folder, plus an optional runtime-loaded CUDA plugin interface. The notebook launches a precompiled Swift executable directly; Python only mounts Drive, configures the process environment, and starts that executable.

## Add as a Swift package

Add this dependency to your package manifest:

```swift
.package(url: "https://github.com/tortudev17/CosmogAI.git", branch: "main")
```

Then add the `CosmogAI` product to the target that uses it:

```swift
.product(name: "CosmogAI", package: "CosmogAI")
```

The package also provides the `cosmogai` command-line executable. Clone the repository with `git clone https://github.com/tortudev17/CosmogAI.git` to build it directly.

## Drive layout

The notebook expects this layout in Google Drive:

```text
MyDrive/
└── CosmogAI/
    ├── cosmogai                 # compiled Swift executable
    ├── libcosmogai_cuda.so      # optional CUDA plugin
    └── ...                      # input and output files
```

In Colab, the notebook path is `/content/drive/MyDrive/CosmogAI`. The executable must be a Linux binary for the runtime's CPU architecture and a compatible glibc version. A macOS binary will not run in Colab's Linux environment. Build and install from a compatible Linux Swift toolchain with the Drive folder mounted:

```bash
export COSMOGAI_DRIVE_ROOT=/path/to/MyDrive/CosmogAI
./Scripts/install-to-drive.sh
```

The script creates the folder if needed and installs the release executable there. It needs to run in a Linux environment with Swift installed. The notebook does not compile Swift on startup.

From macOS, build a Linux x86_64 artifact with Docker Desktop running:

```bash
./Scripts/build-linux-amd64.sh
```

This uses the official Swift 6.4.1 Ubuntu 22.04 image and writes `Artifacts/cosmogai-linux-x86_64`. The binary statically includes the Swift runtime; it still uses the normal Linux C runtime libraries.

## Swift Drive API

Set `COSMOGAI_DRIVE_ROOT` to the `CosmogAI` folder. Paths passed to the library are relative to that folder; parent traversal and absolute paths are rejected.

```swift
import CosmogAI
import Foundation

let input = try readFromDrive("input.bin")
try writeToDrive("results/output.bin", data: input, atomically: false)

// Or keep an explicit store:
let drive = try DriveStore()
let bytes = try drive.readFromDrive("input.bin")
try drive.writeToDrive("results/copy.bin", data: bytes)
```

Reads use `Data(contentsOf:options: [.mappedIfSafe])` to avoid an intermediate copy when supported. Writes default to direct writes for speed; pass `atomically: true` when the file should not be left partially written if the process stops mid-write. Parent directories are created automatically for writes.

The sample executable accepts `--read <relative-path>`, `--write <relative-path> <text...>`, and `--cuda-transform <plugin> <input> <output> [capacity]`. With no arguments it prints the configured Drive root.

## CUDA

The notebook preserves the runtime's CUDA environment and lets you set `CUDA_VISIBLE_DEVICES` in its configuration cell. It does not import PyTorch, TensorFlow, or another Python GPU stack. To run GPU work, compile the CUDA plugin for the Linux runtime with a compatible NVIDIA driver and CUDA runtime installed. Keep the plugin next to the executable as `libcosmogai_cuda.so`.

`CUDAPlugin` loads a shared library only when requested, so CPU-only builds do not depend on CUDA. The plugin exports this C ABI function. A sample bytewise XOR kernel is in `Examples/CUDAPlugin.cu`; compile it on a CUDA-enabled Linux runtime with:

```bash
nvcc -O3 -shared -Xcompiler=-fPIC Examples/CUDAPlugin.cu \
  -o "$COSMOGAI_DRIVE_ROOT/libcosmogai_cuda.so"
```

The Swift runner can then apply that plugin to a Drive file:

```python
PROGRAM_ARGS = ["--cuda-transform", "libcosmogai_cuda.so", "input.bin", "gpu-output.bin"]
```

The plugin exports this C ABI function:

```c
#include <stdint.h>

int32_t cosmogai_cuda_transform(
    const uint8_t *input,
    uint64_t input_size,
    uint8_t *output,
    uint64_t output_capacity,
    uint64_t *output_size
);
```

Return `0` on success, write at most `output_capacity` bytes, and set `*output_size`. By default, the Swift wrapper allocates an output buffer the same size as the input; pass `outputCapacity:` to `transform` when an operation can expand its output. The plugin can copy data to GPU memory, run CUDA kernels, and copy results back. This keeps CUDA linkage and kernel code out of the Swift library while allowing compiled Swift application code to invoke GPU work through `CUDAPlugin`.

```swift
let pluginPath = try DriveStore().rootURL.appendingPathComponent("libcosmogai_cuda.so")
let cuda = try CUDAPlugin(libraryAt: pluginPath)
let output = try cuda.transform(input)
// For an operation that may produce larger output:
// let output = try cuda.transform(input, outputCapacity: 16 * 1024 * 1024)
try writeToDrive("results/gpu-output.bin", data: output)
```

## Notebook

Open `Notebooks/run_cosmogai_from_drive.ipynb` in Colab and run top to bottom. It mounts Drive, checks for the compiled executable, sets `COSMOGAI_DRIVE_ROOT`, and launches the binary. Set `PROGRAM_ARGS` to pass arguments. If the Drive mount blocks execution, it makes a cached local copy in `/tmp` and runs that copy; the Swift process still reads and writes the mounted Drive folder.
