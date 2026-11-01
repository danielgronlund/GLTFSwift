#ifndef GLTF_CMESHOPT_H
#define GLTF_CMESHOPT_H
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif
// Modes: 0 ATTRIBUTES, 1 TRIANGLES, 2 INDICES. Filters: 0 NONE, 1 OCTAHEDRAL, 2 QUATERNION, 3 EXPONENTIAL.
int gltf_meshopt_decode(void *destination, size_t output_size, const unsigned char *source,
                        size_t source_size, size_t count, size_t stride, int mode, int filter);
#ifdef __cplusplus
}
#endif
#endif
