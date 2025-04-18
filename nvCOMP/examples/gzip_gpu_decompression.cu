/*
 * SPDX-FileCopyrightText: Copyright (c) 2020-2025 NVIDIA CORPORATION & AFFILIATES.
 * All rights reserved. SPDX-License-Identifier: LicenseRef-NvidiaProprietary
 *
 * NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
 * property and proprietary rights in and to this material, related
 * documentation and any modifications thereto. Any use, reproduction,
 * disclosure or distribution of this material and related documentation
 * without an express license agreement from NVIDIA CORPORATION or
 * its affiliates is strictly prohibited.
*/

#include "zlib.h"
#include "nvcomp/gzip.h"
#include "BatchData.h"


static void run_example(const std::vector<std::vector<char>>& data,
                        size_t warmup_iteration_count, size_t total_iteration_count)
{
  assert(!data.empty());
  if(warmup_iteration_count >= total_iteration_count) {
    throw std::runtime_error("ERROR: the total iteration count must be greater than the warmup iteration count");
  }

  size_t total_bytes = 0;
  for (const std::vector<char>& part : data) {
    total_bytes += part.size();
  }

  std::cout << "----------" << std::endl;
  std::cout << "files: " << data.size() << std::endl;
  std::cout << "uncompressed (B): " << total_bytes << std::endl;

  const size_t chunk_size = 1 << 16;

  // Build up input batch on CPU
  BatchDataCPU input_data_cpu(data, chunk_size);
  const size_t chunk_count = input_data_cpu.size();
  std::cout << "chunks: " << chunk_count << std::endl;

  // compression

  // Allocate and prepare output/compressed batch
  BatchDataCPU compressed_data_cpu(
      chunk_size, chunk_count);

  // loop over chunks on the CPU, compressing each one
  for (size_t i = 0; i < chunk_count; ++i) {
   //zlib::deflate
   z_stream zs;
   zs.zalloc = NULL; zs.zfree = NULL;
   zs.msg = NULL;
   zs.next_in  = (Bytef *)input_data_cpu.ptrs()[i];
   zs.avail_in = static_cast<uInt>(input_data_cpu.sizes()[i]);
   zs.next_out = (Bytef *)compressed_data_cpu.ptrs()[i];
   zs.avail_out = static_cast<uInt>(input_data_cpu.sizes()[i]);
   int strategy = Z_DEFAULT_STRATEGY;
   // 15 | 16 to enable gzip header
   int ret = deflateInit2(&zs, 9, Z_DEFLATED, 15 | 16, 8, strategy);
   if (ret!=Z_OK) {
       throw std::runtime_error("Call to deflateInit2 failed: " + std::to_string(ret));
   }
   if ((ret = deflate(&zs, Z_FINISH)) != Z_STREAM_END) {
       throw std::runtime_error("Gzip operation failed: " + std::to_string(ret));
   }
   if ((ret = deflateEnd(&zs)) != Z_OK) {
       throw std::runtime_error("Call to deflateEnd failed: " + std::to_string(ret));
   }
   // set the actual compressed size
   compressed_data_cpu.sizes()[i] = zs.total_out;
  }

  // compute compression ratio
  size_t* compressed_sizes_host = compressed_data_cpu.sizes();
  size_t comp_bytes = 0;
  for (size_t i = 0; i < chunk_count; ++i)
    comp_bytes += compressed_sizes_host[i];

  std::cout << "comp_size: " << comp_bytes
            << ", compressed ratio: " << std::fixed << std::setprecision(2)
            << (double)total_bytes / comp_bytes << std::endl;

  // Copy compressed data to GPU
  BatchData compressed_data(compressed_data_cpu, true, nvcompBatchedGzipDecompressRequiredAlignments.input);

  // Allocate and build up decompression batch on GPU
  BatchData decomp_data(input_data_cpu, false, nvcompBatchedGzipDecompressRequiredAlignments.output);

  // Create CUDA stream
  cudaStream_t stream;
  CUDA_CHECK(cudaStreamCreate(&stream));

  // CUDA events to measure decompression time
  cudaEvent_t start, end;
  CUDA_CHECK(cudaEventCreate(&start));
  CUDA_CHECK(cudaEventCreate(&end));

  // deflate GPU decompression
  size_t decomp_temp_bytes;
  nvcompStatus_t status = nvcompBatchedGzipDecompressGetTempSize(
      chunk_count, chunk_size, &decomp_temp_bytes);
  if (status != nvcompSuccess) {
    throw std::runtime_error("nvcompBatchedGzipDecompressGetTempSize() failed.");
  }

  void* d_decomp_temp;
  CUDA_CHECK(cudaMalloc(&d_decomp_temp, decomp_temp_bytes));

  size_t* d_decomp_sizes;
  CUDA_CHECK(cudaMalloc(&d_decomp_sizes, chunk_count * sizeof(size_t)));

  nvcompStatus_t* d_status_ptrs;
  CUDA_CHECK(cudaMalloc(&d_status_ptrs, chunk_count * sizeof(nvcompStatus_t)));

  CUDA_CHECK(cudaStreamSynchronize(stream));

  auto perform_decompression = [&]() {
    if (nvcompBatchedGzipDecompressAsync(
          compressed_data.ptrs(),
          compressed_data.sizes(),
          decomp_data.sizes(),
          d_decomp_sizes,
          chunk_count,
          d_decomp_temp,
          decomp_temp_bytes,
          decomp_data.ptrs(),
          d_status_ptrs,
          stream) != nvcompSuccess) {
      throw std::runtime_error("ERROR: nvcompBatchedGzipDecompressAsync() not successful");
    }
  };

  // Run warm-up decompression
  for (size_t iter = 0; iter < warmup_iteration_count; ++iter) {
    perform_decompression();
  }

  // Validate decompressed data against input
  if (!(input_data_cpu == decomp_data)) {
    throw std::runtime_error("Failed to validate decompressed data");
  } else {
    std::cout << "decompression validated :)" << std::endl;
  }

  // Re-run decompression to get throughput
  CUDA_CHECK(cudaEventRecord(start, stream));
  for (size_t iter = warmup_iteration_count; iter < total_iteration_count; ++iter) {
    perform_decompression();
  }
  CUDA_CHECK(cudaEventRecord(end, stream));
  CUDA_CHECK(cudaStreamSynchronize(stream));

  float ms;
  CUDA_CHECK(cudaEventElapsedTime(&ms, start, end));
  ms /= total_iteration_count - warmup_iteration_count;

  double decompression_throughput = ((double)total_bytes / ms) * 1e-6;
  std::cout << "decompression throughput (GB/s): " << decompression_throughput
            << std::endl;

  CUDA_CHECK(cudaFree(d_decomp_temp));
  CUDA_CHECK(cudaFree(d_decomp_sizes));
  CUDA_CHECK(cudaFree(d_status_ptrs));

  CUDA_CHECK(cudaEventDestroy(start));
  CUDA_CHECK(cudaEventDestroy(end));
  CUDA_CHECK(cudaStreamDestroy(stream));
}

int main(int argc, char* argv[])
{
  std::vector<std::string> file_names;

  size_t warmup_iteration_count = 2;
  size_t total_iteration_count = 5;

  do {
    if (argc < 3) {
      break;
    }

    int i = 1;
    while (i < argc) {
      const char* current_argv = argv[i++];
      if (strcmp(current_argv, "-f") == 0) {
        // parse until next `-` argument
        while (i < argc && argv[i][0] != '-') {
          file_names.emplace_back(argv[i++]);
        }
      } else {
        std::cerr << "Unknown argument: " << current_argv << std::endl;
        return 1;
      }
    }
  } while (0);

  if (file_names.empty()) {
    std::cerr << "Must specify at least one file via '-f <file>'." << std::endl;
    return 1;
  }

  auto data = multi_file(file_names);

  run_example(data, warmup_iteration_count, total_iteration_count);

  return 0;
}
