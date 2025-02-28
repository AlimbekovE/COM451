/**************************************************************************
*
*     set up GPU for processing
*
**************************************************************************/

#include "gpu_main.h"
#include <cuda.h>
#include <stdio.h>

// #include <cuda_runtime.h>

#define BackgroundRed 0.0f
#define BackgroundGreen 0.0f
#define BackgroundBlue 0.0f


#define AttractorRed 0.709f

#define AttractorGreen 0.500f
#define AttractorBlue 0.0

#define zInitialSize 3
#define zScale 1.1f
#define FadeSpeed 0.01f
#define HeatTransferSpeed 0.05f

texture<float, 2> texRed;
texture<float, 2> texGreen;
texture<float, 2> texBlue;

/******************************************************************************/
GPU_Palette initGPUPalette(unsigned int imageWidth, unsigned int imageHeight)
{
    GPU_Palette X;

    X.gThreads.x = 32; // 32 x 32 = 1024 threads per block
    X.gThreads.y = 32;
    X.gThreads.z = 1;
    X.gBlocks.x = ceil(imageWidth / 32); // however many blocks ng++ -w -c interface.cpp $(F1) $(F2) $(F3) $(F4)eeded for image
    X.gBlocks.y = ceil(imageHeight / 32);
    X.gBlocks.z = 1;

    X.palette_width = imageWidth; // save this info
    X.palette_height = imageHeight;
    X.num_pixels = imageWidth * imageHeight;

    // allocate memory on GPU corresponding to pixel colors:
    cudaError_t err;
    err = cudaMalloc((void**)&X.red, X.num_pixels * sizeof(float));
    if (err != cudaSuccess) {
        printf("cuda error allocating red = %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    cudaMalloc((void**)&X.green, X.num_pixels * sizeof(float)); // g
    if (err != cudaSuccess) {
        printf("cuda error allocating green = %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }
    cudaMalloc((void**)&X.blue, X.num_pixels * sizeof(float)); // b
    if (err != cudaSuccess) {
        printf("cuda error allocating blue = %s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    cudaChannelFormatDesc desc = cudaCreateChannelDesc<float>();

    cudaBindTexture2D(NULL, texRed, X.red, desc, imageWidth, imageHeight, sizeof(float) * imageWidth);
    cudaBindTexture2D(NULL, texGreen, X.red, desc, imageWidth, imageHeight, sizeof(float) * imageWidth);
    cudaBindTexture2D(NULL, texBlue, X.red, desc, imageWidth, imageHeight, sizeof(float) * imageWidth);

    return X;
}

/******************************************************************************/
void freeGPUPalette(GPU_Palette* P)
{
    cudaUnbindTexture(texRed);
    cudaUnbindTexture(texGreen);
    cudaUnbindTexture(texBlue);

    cudaFree(P->red);
    cudaFree(P->green);
    cudaFree(P->blue);
}

/******************************************************************************/
int updatePalette(GPU_Palette* P, APoint (&points)[5])
// int updatePalette(GPU_Palette* P, int xIdx, int yIdx)
{
    for (int i = 0; i < 5; i++) {
        updateReds<<<P->gBlocks, P->gThreads>>>(P->red, points[i].xIdx, points[i].yIdx, points[i].z);
        updateGreens<<<P->gBlocks, P->gThreads>>>(P->green, points[i].xIdx, points[i].yIdx, points[i].z);
        updateBlues<<<P->gBlocks, P->gThreads>>>(P->blue, points[i].xIdx, points[i].yIdx, points[i].z);
    }
    return 0;
}

/******************************************************************************/
__global__ void updateReds(float* red, int xIdx, int yIdx, float zIdx)
{

    // float size = 5 + (zIdx * 0.1);
    float size = zInitialSize + zIdx * zScale;
    int x = threadIdx.x + (blockIdx.x * blockDim.x);
    int y = threadIdx.y + (blockIdx.y * blockDim.y);
    int vecIdx = x + (y * blockDim.x * gridDim.x);

    float top, left, center, right, bot;

    top = tex2D(texRed, x, y + 1);
    left = tex2D(texRed, x - 1, y);
    center = tex2D(texRed, x, y);
    right = tex2D(texRed, x + 1, y);
    bot = tex2D(texRed, x, y - 1);

    // red[vecIdx] =(top + bot + right + left + center) / 5.0;

    if (sqrtf(powf((x - xIdx), 2) + powf((y - yIdx), 2)) < size) {

        red[vecIdx] = AttractorRed;

    } else {

        float heat_average = (top + bot + right + left + center) / (5 - HeatTransferSpeed);

        // if (heat_average > BackgroundRed) {
        //     red[vecIdx] += 0.001;
        // }

        if (heat_average >= AttractorRed) {
            red[vecIdx] = AttractorRed / 2;
        } else {
            red[vecIdx] = heat_average;
        }

        red[vecIdx] -= FadeSpeed * red[vecIdx];

        if (red[vecIdx] < BackgroundRed)
            red[vecIdx] = BackgroundRed;
        if (red[vecIdx] > AttractorRed)
            red[vecIdx] = AttractorRed;
    }
}

/******************************************************************************/
__global__ void updateGreens(float* green, int xIdx, int yIdx, float zIdx)
{

    float size = zInitialSize + zIdx * zScale;
    int x = threadIdx.x + (blockIdx.x * blockDim.x);
    int y = threadIdx.y + (blockIdx.y * blockDim.y);
    int vecIdx = x + (y * blockDim.x * gridDim.x);

    float top, left, center, right, bot;

    top = tex2D(texRed, x, y + 1);
    left = tex2D(texRed, x - 1, y);
    center = tex2D(texRed, x, y);
    right = tex2D(texRed, x + 1, y);
    bot = tex2D(texRed, x, y - 1);

    // green[vecIdx] = center + HeatTransfered * center);
    // green[vecIdx] =(top + bot + right + left + center) / 5.0;

    if (sqrtf(powf((x - xIdx), 2) + powf((y - yIdx), 2)) < size) {

        green[vecIdx] = AttractorGreen;

    } else {

        float heat_average = (top + bot + right + left + center) / (5 - HeatTransferSpeed);

        if (heat_average >= AttractorGreen) {
            green[vecIdx] = AttractorGreen / 2;
        } else {
            green[vecIdx] = heat_average;
        }


        green[vecIdx] -= FadeSpeed * green[vecIdx];

        if (green[vecIdx] < BackgroundGreen)
            green[vecIdx] = BackgroundGreen;
        if (green[vecIdx] > AttractorGreen)
            green[vecIdx] = AttractorGreen;

    }
}

/******************************************************************************/
__global__ void updateBlues(float* blue, int xIdx, int yIdx, float zIdx)
{

    float size = zInitialSize + zIdx * zScale;
    int x = threadIdx.x + (blockIdx.x * blockDim.x);
    int y = threadIdx.y + (blockIdx.y * blockDim.y);
    int vecIdx = x + (y * blockDim.x * gridDim.x);

    float top, left, center, right, bot;

    top = tex2D(texRed, x, y + 1);
    left = tex2D(texRed, x - 1, y);
    center = tex2D(texRed, x, y);
    right = tex2D(texRed, x + 1, y);
    bot = tex2D(texRed, x, y - 1);

    // blue[vecIdx] = center + FadeSpeed * (top + bot + right + left - 4 * center);
    // blue[vecIdx] =(top + bot + right + left + center) / 5.0;

    if (sqrtf(powf((x - xIdx), 2) + powf((y - yIdx), 2)) < size) {

        blue[vecIdx] = AttractorBlue;

    } else {

         blue[vecIdx] -= FadeSpeed * blue[vecIdx];

        if (blue[vecIdx] < BackgroundBlue)
            blue[vecIdx] = BackgroundBlue;
        // if (blue[vecIdx] > AttractorBlue)
        //     blue[vecIdx] = AttractorBlue;
    }
}

/******************************************************************************/
