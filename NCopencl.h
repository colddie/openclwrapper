// The following ifdef block is the standard way of creating macros which make exporting 
// from a DLL simpler. All files within this DLL are compiled with the NCPROJ_OPENCL_EXPORTS
// symbol defined on the command line. This symbol should not be defined on any project
// that uses this DLL. This way any other project whose source files include this file see 
// NCPROJ_OPENCL_API functions as being imported from a DLL, whereas this DLL sees symbols
// defined with this macro as being exported.

#pragma once


#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files:
#ifdef WIN32
	#include <windows.h>
	#include <SDKDDKVer.h>
	#define DLL_EXPORT extern "C" __declspec(dllexport)
	// This disables the Visual Studio warnings on fopen, 
	// strcat and strcpy with the advice to use the _s version
	#pragma warning (disable : 4996)
#else
	#define DLL_EXPORT extern "C"
#endif

#define MAX_KERNELS 16
#define MAX_BUFFERS 16

// Definition of IDL string
typedef struct{
	short slen;
	short stype;
	char* s;
} idls;

// Reference additional headers your program requires here
#include <CL/cl.h>
#include <CL/cl_ext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <CL/opencl.h>

//
DLL_EXPORT int fNCbuild_kernels(int argc, void *argv[]);
DLL_EXPORT int fNCcreate_buffer(int argc, void *argv[]);
DLL_EXPORT int fNCcreate_command_queue(int argc, void *argv[]);
DLL_EXPORT int fNCexecute_kernel(int argc, void* argv[]);
DLL_EXPORT int fNCread_buffer(int argc, void *argv[]);
DLL_EXPORT int fNCrelease_buffer(int argc, void *argv[]);
DLL_EXPORT int fNCrelease_command_queue(int argc, void *argv[]);
DLL_EXPORT int fNCrelease_kernels(int argc, void *argv[]);
DLL_EXPORT int fNCset_kernel_arg(int argc, void *argv[]);
DLL_EXPORT int fNCunload(int argc, void* argv[]);
DLL_EXPORT int fNCwrite_buffer(int argc, void* argv[]);

//
DLL_EXPORT int fNCcreate_image(int argc, void *argv[]);
DLL_EXPORT int fNCrelease_image(int argc, void *argv[]);
DLL_EXPORT int fNCread_image(int argc, void *argv[]);
DLL_EXPORT int fNCwrite_image(int argc, void *argv[]);