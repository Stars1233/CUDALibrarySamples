# C2C Sample without descriptors
## Sample description
This sample is similar to [samples/c2c_no_descriptors](../c2c_no_descriptors/README.md), where it performs
- C2C forward transform
- [Scaling/normalization](../common/README.md)
- C2C backward transform.

But this sample uses the new API `cufftMpMakePlan3d` where the communicator is passed directly to the planning function.

## Build and run
See [Requirements](../../README.md) and [Quick start for C++ samples](../../README.md) for hardware/software requirements and build instructions.

Example code snippet:
```
$ MPI_HOME=/usr/lib/x86_64-linux-gnu/openmpi/ make run
[...]
Hello from rank 1/2 using GPU 1 transform of size 16 x 16 x 16, local size 8 x 16 x 16
Hello from rank 0/2 using GPU 0 transform of size 16 x 16 x 16, local size 8 x 16 x 16
GPU data (after first transform): global 3D index [0 0 0], local index 0, rank 0 is (47.305470,11.079344)
GPU data (after first transform): global 3D index [0 0 1], local index 1, rank 0 is (26.524790,-34.719849)
GPU data (after first transform): global 3D index [0 0 2], local index 2, rank 0 is (18.168295,10.271091)
GPU data (after first transform): global 3D index [0 0 3], local index 3, rank 0 is (-18.064495,-11.214562)
GPU data (after first transform): global 3D index [0 0 4], local index 4, rank 0 is (-32.529343,-17.200300)
GPU data (after first transform): global 3D index [0 0 5], local index 5, rank 0 is (-59.918392,3.244051)
GPU data (after first transform): global 3D index [0 0 6], local index 6, rank 0 is (8.896272,49.572002)
GPU data (after first transform): global 3D index [0 0 7], local index 7, rank 0 is (9.677225,34.718925)
GPU data (after first transform): global 3D index [0 0 8], local index 8, rank 0 is (-37.462101,-9.240517)
GPU data (after first transform): global 3D index [0 0 9], local index 9, rank 0 is (15.618601,-9.228624)
GPU data (after first transform): global 3D index [0 8 0], local index 0, rank 1 is (-13.323235,-48.004234)
GPU data (after first transform): global 3D index [0 8 1], local index 1, rank 1 is (-39.105301,-68.343224)
GPU data (after first transform): global 3D index [0 8 2], local index 2, rank 1 is (11.424836,-28.157215)
GPU data (after first transform): global 3D index [0 8 3], local index 3, rank 1 is (-7.653571,-3.823595)
GPU data (after first transform): global 3D index [0 8 4], local index 4, rank 1 is (-34.110542,22.107759)
GPU data (after first transform): global 3D index [0 8 5], local index 5, rank 1 is (-31.391949,-60.248703)
GPU data (after first transform): global 3D index [0 8 6], local index 6, rank 1 is (54.438560,14.854652)
GPU data (after first transform): global 3D index [0 8 7], local index 7, rank 1 is (8.685278,-13.184855)
GPU data (after first transform): global 3D index [0 8 8], local index 8, rank 1 is (-44.494644,9.475269)
GPU data (after first transform): global 3D index [0 8 9], local index 9, rank 1 is (-63.778786,18.937965)
PASSED with L2 error 1.978186e-07 < 1.000000e-06
```