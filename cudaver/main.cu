#include <stdio.h>
#include <png.h>
#include <stdlib.h>

__device__ double distance(double x, double y) {
    return abs((x * x + y * y) - 4);
}

__global__ void calc(int imgx, int imgy, char *cmem) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i > imgx * imgy) {
        return;
    }
    int x = i % imgx;
    int y = i / imgx;

    double sx = -0.4;
    double ex = 0.1;
    double sy = 0.67;
    double ey = 1.17;

    double cx = (double)x / imgx * (ex - sx) + sx;
    double cy = (double)y / imgy * (ey - sy) + sy;

    double zx = 0;
    double zy = 0;

    double d = 1e6;

    for(int j = 0; j < 10000; j++) {
        double tx = zx;
        zx = zx * zx - zy * zy + cx;
        zy = 2 * tx * zy + cy;
        if (d > distance(zx, zy)) {
            d = distance(zx, zy);
        }
    }

    char c = 255 / (1 + d);
    if (distance(zx, zy) < 4) {
        c = 0;
    }
    cmem[3 * i + 0] = c;
    cmem[3 * i + 1] = c;
    cmem[3 * i + 2] = c;
}

int main(void) {
    int imgx = 4000;
    int imgy = 4000;

    char *cmem;

    cudaMalloc(&cmem, sizeof(char) * imgx * imgy * 3);

    int bs = 32;

    calc<<<(imgx*imgy+bs-1)/bs, bs>>>(imgx, imgy, cmem);


    // open write file
    // https://daeudaeu.com/libpng/ のpngFileEncodeWriteを参考
    FILE *fo;
    int j;

    png_structp png;
    png_infop info;
    png_bytepp datap;
    png_byte type;

    fo = fopen("img.png", "wb");
    if (fo == NULL) {
        return 1;
    }

    png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    info = png_create_info_struct(png);

    type = PNG_COLOR_TYPE_RGB;

    png_init_io(png, fo);
    png_set_IHDR(png, info, imgx, imgy, 8, type, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);

    datap = (png_bytepp)png_malloc(png, sizeof(png_bytep) * imgy);

    png_set_rows(png, info, datap);

    for (j = 0; j < imgy; j++) {
        datap[j] = (png_bytep)png_malloc(png, 3 * imgx);

        // cmemはyが反転しているので上下反転する
        cudaMemcpy(datap[j], cmem + 3 * (imgy - j - 1) * imgx, 3 * imgx, cudaMemcpyDefault);
    }
    png_write_png(png, info, PNG_TRANSFORM_IDENTITY, NULL);

    cudaFree(cmem);

    for (j = 0; j < imgy; j++) {
        png_free(png, datap[j]);
    }
    png_free(png, datap);

    png_destroy_write_struct(&png, &info);
    fclose(fo);

    return 0;
}