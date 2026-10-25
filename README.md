# CosmogAI Swift library

CosmogAI is a Swift package for fast file access beneath a mounted Google Drive folder, with an optional runtime-loaded CUDA plugin interface.

## Add as a Swift package

Add the repository to your package manifest:

```swift
.package(url: "https://github.com/tortudev17/CosmogAI.git", branch: "main")
```

Then add the product to the target that uses it:

```swift
.product(name: "CosmogAI", package: "CosmogAI")
```

## Drive file access

Set `COSMOGAI_DRIVE_ROOT` to the mounted `MyDrive/CosmogAI` folder. Library paths are relative to this root; absolute paths and `.` or `..` components are rejected.

```swift
import CosmogAI

let bytes = try readFromDrive("input.bin")
try writeToDrive("results/output.bin", data: bytes)
```

Or use an explicit store:

```swift
let drive = try DriveStore()
let bytes = try drive.readFromDrive("input.bin")
try drive.writeToDrive("results/copy.bin", data: bytes)
```

Reads use memory mapping when supported. Writes default to direct writes for speed; use `atomically: true` when protection against partial writes matters. Parent directories are created automatically.

## Optional CUDA plugin

`CUDAPlugin` loads a shared library only when requested, so CPU-only builds do not link against CUDA. The shared library must export `cosmogai_cuda_transform` with this C ABI:

```c
int32_t cosmogai_cuda_transform(
    const uint8_t *input,
    uint64_t input_size,
    uint8_t *output,
    uint64_t output_capacity,
    uint64_t *output_size
);
```

Compile the example on a CUDA-enabled Linux machine with `nvcc`:

```bash
nvcc -O3 -shared -Xcompiler=-fPIC Examples/CUDAPlugin.cu \
  -o "$COSMOGAI_DRIVE_ROOT/libcosmogai_cuda.so"
```

The plugin can copy data to GPU memory, run kernels, and copy results back. The Swift wrapper returns an error for failed plugin calls and output sizes that exceed the supplied capacity.

## Build

Build the package and `cosmogai` command-line executable with Swift Package Manager:

```bash
swift build -c release
```
