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

## Prepare the executable for Google Colab

The Colab notebook is stored in Google Drive at `My Drive/CosmogAI/run_cosmogai_from_drive.ipynb`. It expects a *(Linux x86_64 executable** named exactly `cosmogai` at:

```text
My Drive/CosmogAI/cosmogai
```

After it mounts Drive, Colab sees that file at `/content/drive/MyDrive/CosmogAI/cosmogai`. The notebook checks for this path and runs the executable directly. It does not build Swift code when you open or run the notebook.

### Build it on your Mac

Install and start Docker Desktop, then clone or update this repository and build the Linux executable:

```bash
git clone https://github.com/tortudev17/CosmogAI.git
cd CosmogAI
./Scripts/build-linux-amd64.sh
```

If you already cloned it, run `git pull `inside the repository instead of cloning again. The script builds for Linux x86_64 in the Swift Ubuntu container and writes the result to:

```text
Artifacts/cosmogai-linux-x86_64
```

This is a Linux binary; do not upload a macOS executable from `.build` or rename the Linux artifact with a `.dylib` or `.so` extension.

### Put it in Google Drive

Copy the artifact into the synced `My Drive/CosmogAI` folder and give the copy the exact name `cosmogai` (no extension). If Google Drive for desktop is syncing Drive on your Mac, set the local path to that folder and copy it like this:

```bash
export COSMOGAI_DRIVE_ROOT="/path/to/Google Drive/My Drive/CosmogAI"
mkdir -p "$COSMOGAI_DRIVE_ROOT"
cp Artifacts/cosmogai-linux-x86_64 "$COSMOGAI_DRIVE_ROOT/cosmogai"
chmod 755 "$COSMOGAI_DRIVE_ROOT/cosmogai"
```

Replace the example path with the actual local `My Drive/CosmogAI` path shown by Google Drive for desktop. Alternatively, upload `Artifacts/cosmogai-linux-x86_64` through the Google Drive website into `My Drive/CosmogAI`, then rename the uploaded file to `cosmogai`. Keep the notebook and executable in that same Drive folder.

### Run the notebook

Open `My Drive/CosmogAI/run_cosmogai_from_drive.ipynb` in Colab while signed into the Google account that can access the folder, connect a runtime, and run the notebook cells from top to bottom (or choose **Runtime → Run all**). The notebook mounts Drive, verifies the executable path, sets `COSMOGAI_DRIVE_ROOT` to `/content/drive/MyDrive/CosmogAI`, then launches `cosmogai`. Set `PROGRAM_ARGS` in its configuration cell to pass runner arguments. If Drive does not allow execution from its mount, the notebook makes a cached copy in `/tmp` and runs it from there.

For GPU use, select a Colab GPU runtime. The executable can use CUDA only when a compatible `libcosmogai_cuda.so` is also present in `My Drive/CosmogAI` and the program is configured to invoke it; selecting a GPU alone does not make CPU code use CUDA. See [Optional CUDA plugin](#optional-cuda-plugin) for the plugin interface and build example.
