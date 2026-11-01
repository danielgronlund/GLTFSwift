#include "CMeshopt.h"
#include <meshoptimizer.h>
#include <stdint.h>
int gltf_meshopt_decode(void *destination, size_t output_size, const unsigned char *source,
                        size_t source_size, size_t count, size_t stride, int mode, int filter) {
  if (!destination || !source || !count || !stride || count > SIZE_MAX / stride || count * stride != output_size) return -10;
  int status;
  if (mode == 0) {
    if (stride > 256 || stride % 4 != 0) return -11;
    if (filter < 0 || filter > 3 || (filter == 1 && stride != 4 && stride != 8) ||
        (filter == 2 && stride != 8)) return -12;
    status = meshopt_decodeVertexBuffer(destination, count, stride, source, source_size);
  } else {
    if ((stride != 2 && stride != 4) || filter != 0) return -13;
    if (mode == 1 && count % 3 == 0) status = meshopt_decodeIndexBuffer(destination, count, stride, source, source_size);
    else if (mode == 2) status = meshopt_decodeIndexSequence(destination, count, stride, source, source_size);
    else return -14;
  }
  if (status != 0) return status;
  if (filter == 1) meshopt_decodeFilterOct(destination, count, stride);
  if (filter == 2) meshopt_decodeFilterQuat(destination, count, stride);
  if (filter == 3) meshopt_decodeFilterExp(destination, count, stride);
  return 0;
}
