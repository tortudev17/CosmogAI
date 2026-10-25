#include <cuda_runtime.h>
#include <cstdint>

__global__ static void xorBytes(const uint8_t *input, uint8_t *output,
                                uint64_t length, uint8_t mask) {
    const uint64_t index = static_cast<uint64_t>(blockIdx.x) * blockDim.x + threadIdx.x;
    if (index < length) {
        output[index] = input[index] ^ mask;
    }
}

// Implements the ABI loaded by CosmogAI.CUDAPlugin. This sample applies a
// byte-wise XOR mask; replace the kernel with the desired GPU operation.
extern "C" int32_t cosmogai_cuda_transform(const uint8_t *input,
                                           uint64_t input_size,
                                           uint8_t *output,
                                           uint64_t output_capacity,
                                           uint64_t *output_size) {
    if (output_size == nullptr || (input_size > 0 && (input == nullptr || output == nullptr))) {
        return -1001;
    }
    if (input_size > output_capacity) {
        return -1002;
    }
    if (input_size == 0) {
        *output_size = 0;
        return 0;
    }

    void *device_input = nullptr;
    void *device_output = nullptr;
    cudaError_t status = cudaMalloc(&device_input, static_cast<size_t>(input_size));
    if (status != cudaSuccess) return static_cast<int32_t>(status);
    status = cudaMalloc(&device_output, static_cast<size_t>(input_size));
    if (status != cudaSuccess) {
        cudaFree(device_input);
        return static_cast<int32_t>(status);
    }

    status = cudaMemcpy(device_input, input, static_cast<size_t>(input_size), cudaMemcpyHostToDevice);
    if (status == cudaSuccess) {
        const unsigned int threads = 256;
        const unsigned int blocks = static_cast<unsigned int>((input_size + threads - 1) / threads);
        xorBytes<<<blocks, threads>>>(static_cast<const uint8_t *>(device_input),
                                      static_cast<uint8_t *>(device_output), input_size, 0x5a);
        status = cudaGetLastError();
    }
    if (status == cudaSuccess) {
        status = cudaDeviceSynchronize();
    }
    if (status == cudaSuccess) {
        status = cudaMemcpy(output, device_output, static_cast<size_t>(input_size), cudaMemcpyDeviceToHost);
    }

    cudaFree(device_output);
    cudaFree(device_input);
    if (status != cudaSuccess) return static_cast<int32_t>(status);
    *output_size = input_size;
    return 0;
}
