#include "NCopencl.h"

///////////////////////////////////////////////////////////////////////////////
// NVIDIA helper function.
//
char* oclLoadProgSource(const char* cFilename, const char* cPreamble, size_t* szFinalLength)
{
    // locals 
    FILE* pFileStream = NULL;
    size_t szSourceLength;

    // open the OpenCL source code file
    #ifdef _WIN32   // Windows version
        if(fopen_s(&pFileStream, cFilename, "rb") != 0) 
        {       
            return NULL;
        }
    #else           // Linux version
        pFileStream = fopen(cFilename, "rb");
        if(pFileStream == 0) 
        {       
            return NULL;
        }
    #endif

    size_t szPreambleLength = strlen(cPreamble);

    // get the length of the source code
    fseek(pFileStream, 0, SEEK_END); 
    szSourceLength = ftell(pFileStream);
    fseek(pFileStream, 0, SEEK_SET); 

    // allocate a buffer for the source code string and read it in
    char* cSourceString = (char *)malloc(szSourceLength + szPreambleLength + 1); 
    memcpy(cSourceString, cPreamble, szPreambleLength);
    if (fread((cSourceString) + szPreambleLength, szSourceLength, 1, pFileStream) != 1)
    {
        fclose(pFileStream);
        free(cSourceString);
        return 0;
    }

    // close the file and return the total length of the combined (preamble + source) string
    fclose(pFileStream);
    if(szFinalLength != 0)
    {
        *szFinalLength = szSourceLength + szPreambleLength;
    }
    cSourceString[szSourceLength + szPreambleLength] = '\0';

    return cSourceString;
}

///////////////////////////////////////////////////////////////////////////////
// Build a series of kernels.
//
int fBuildKernels(cl_command_queue* commands, cl_kernel kernels[MAX_KERNELS], cl_ulong n_kernels, idls* file_paths, idls* function_names, idls* compile_options, cl_bool verbose, char* log_file)
{
	
	int				error;
	const char*		source;
	cl_context		context;
	cl_device_id	device_id;
	cl_program		program[MAX_KERNELS];
	size_t			kernel_size;
	size_t			build_log_size = 4 * 2048 * sizeof(char);
	char*			build_log = new char[4*2048];
	FILE*			pfile = NULL;

	error = clGetCommandQueueInfo(*commands, CL_QUEUE_CONTEXT, sizeof(cl_context), &context, NULL);

	if (error != CL_SUCCESS)
    {
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to retreive context! %d \n", error);
			fclose(pfile);
		}
		return(-3);
    } else {
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Context retreived.\n");
			fclose(pfile);
		}
	}


	for (int ii = 0; ii < n_kernels; ii++)
	{
		source = oclLoadProgSource(file_paths[ii].s, "", &kernel_size);
		
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Source file nr. %d read.\n", ii);
			fclose(pfile);
		}
		
		program[ii]  = clCreateProgramWithSource(context, 1, &source, &kernel_size, &error);
		
		if (!(program[ii]) || error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				// Error code
				fprintf(pfile, "Error: Failed to create compute program nr. %d! %d \n", ii, error);
				fprintf(pfile, "-30: CL_INVALID_VALUE\n");
				fprintf(pfile, "-34: CL_INVALID_CONTEXT\n");
				fclose(pfile);
			}
		    return(-8);
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Compute program nr. %d created.\n", ii);
				fclose(pfile);
			}
		}

		error = clBuildProgram(program[ii], 0, NULL, compile_options[ii].s, NULL, NULL);

		if (error != CL_SUCCESS) // CL_BUILD_PROGRAM_FAILURE -11
		{
		    if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to build program executable nr. %d! %d \n", ii, error);
				fprintf(pfile, "-11: CL_BUILD_PROGRAM_FAILURE\n");
				fprintf(pfile, "Info: Use the Intel Offline Compiler to debug the kernel. Compile options below.\n");
				fprintf(pfile, compile_options[ii].s);
				fprintf(pfile, "\n");
				
				// Get build info
				fprintf(pfile, "Build log: \n");
				error = clGetCommandQueueInfo(*commands, CL_QUEUE_DEVICE, sizeof(cl_device_id), &device_id, NULL);
				error = clGetProgramBuildInfo(program[ii], device_id, CL_PROGRAM_BUILD_LOG, build_log_size, build_log, NULL);
				fprintf(pfile, build_log);
				fprintf(pfile, "\n");
				fclose(pfile);
			}
		    return(-9);
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Program executable nr. %d built. Compile options:\n", ii);
				fprintf(pfile, compile_options[ii].s);
				fprintf(pfile, "\n");
				fclose(pfile);
			}
		}

		kernels[ii] = clCreateKernel(program[ii], function_names[ii].s, &error);
		if (!(kernels[ii]) || error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to create compute kernel nr. %d! %d\n", ii, error);
				fclose(pfile);
			}
			return(-10);
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Compute kernel nr. %d created.\n", ii);
				fclose(pfile);
			}
		}

	}

	return(0);

}

///////////////////////////////////////////////////////////////////////////////
// Create and fill an OpenCL memmory buffer
//
int fCreateBuffer(cl_command_queue*	commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_int read_write, cl_bool use_host_ptr, cl_bool verbose, char* log_file)
{
	cl_int			error;
	cl_context		context;
	cl_mem_flags	mem_flags;
	FILE*			pfile = NULL;

	error = clGetCommandQueueInfo(*commands, CL_QUEUE_CONTEXT, sizeof(cl_context), &context, NULL);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to retreive context! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Context retreived.\n");
			fclose(pfile);
		}
	}

	if (use_host_ptr) 
	{
		mem_flags = CL_MEM_USE_HOST_PTR;
		*mem_ptr  = clCreateBuffer(context, mem_flags, content_size, content, &error);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to allocate buffer! %d \n", error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Buffer allocated.\n");
				fclose(pfile);
			}
		}
	} 
	else 
	{
		switch (read_write)
		{
			case 0 : 
				mem_flags = CL_MEM_READ_WRITE;
				break;
			case 1 : 
				mem_flags = CL_MEM_WRITE_ONLY;
				break;
			case 2 : 
				mem_flags = CL_MEM_READ_ONLY;
				break;
			default: 
				mem_flags = NULL;
		}

		*mem_ptr = clCreateBuffer(context, mem_flags, content_size, NULL, &error);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to allocate buffer! %d \n", error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Buffer allocated.\n");
				fclose(pfile);
			}
		}

		error    = clEnqueueWriteBuffer(*commands, *mem_ptr, CL_TRUE, 0, content_size, content, 0, NULL, NULL);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to write data to buffer! %d \n", error);
				fprintf(pfile, "Info: Content size (bytes): %lu.\n", content_size);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Data written to buffer.\n");
				fclose(pfile);
			}
		}

	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Create and fill an OpenCL memmory image
//
int fCreateImage(cl_command_queue*	commands, cl_mem* mem_ptr, void* content, cl_uint image_width, cl_uint image_height, cl_uint image_depth, cl_int read_write, cl_bool use_host_ptr, cl_bool verbose, char* log_file)
{
	cl_int			error;
	cl_context		context;
	cl_mem_flags	mem_flags;
	FILE*			pfile = NULL;
	cl_image_format format;
	format.image_channel_order = CL_RGBA;
	format.image_channel_data_type = CL_FLOAT;

	cl_image_desc   desc;
	desc.image_type   = CL_MEM_OBJECT_IMAGE3D;
	desc.image_width  = image_width;
	desc.image_height = image_height;
	desc.image_depth  = image_depth;
	desc.image_array_size = 0;
	desc.image_row_pitch  = 0;
	desc.image_slice_pitch= 0;
	desc.num_mip_levels   = 0;
	desc.num_samples      = 0;
	desc.buffer           = NULL;


	size_t origin[] = {0,0,0};
	size_t region[] = {image_width,image_height,image_depth};


	error = clGetCommandQueueInfo(*commands, CL_QUEUE_CONTEXT, sizeof(cl_context), &context, NULL);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to retreive context! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Context retreived.\n");
			fclose(pfile);
		}
	}

	if (use_host_ptr) 
	{
		mem_flags = CL_MEM_USE_HOST_PTR;
		*mem_ptr  = clCreateImage(context, mem_flags, &format, &desc, content, &error);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to allocate image! %d \n", error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Image allocated.\n");
				fclose(pfile);
			}
		}
	} 
	else 
	{
		switch (read_write)
		{
		case 0 : 
			mem_flags = CL_MEM_READ_WRITE;
			break;
		case 1 : 
			mem_flags = CL_MEM_WRITE_ONLY;
			break;
		case 2 : 
			mem_flags = CL_MEM_READ_ONLY;
			break;
		default: 
			mem_flags = NULL;
		}


		*mem_ptr  = clCreateImage3D(context, mem_flags, &format, image_width, image_height, image_depth, 0, 0, content, &error);
		//*mem_ptr = clCreateImage(context, mem_flags, &format, &desc, content, &error);            ;  OPENCL 1.2 or above


		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to allocate image! %d \n", error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Image allocated.\n");
				fclose(pfile);
			}
		}

		error    = clEnqueueWriteImage(*commands, *mem_ptr, CL_TRUE, origin, region, 0, 0, content, 0, NULL, NULL);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to write data to image! %d \n", error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Data written to image.\n");
				fclose(pfile);
			}
		}

	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Create an OpenCL Command queue from scratch.
//
int fCreateCommandQueue(cl_command_queue*	commands, cl_bool force_cpu, cl_bool verbose, char*	log_file)
{
	cl_platform_id*		platform_id;
	cl_uint             platform_nn;      // number of platforms
	cl_device_id*	    device_list;
	cl_device_id		device_id;
	cl_context			context;
	cl_uint				gpu_nn = 0;
	cl_uint				cpu_nn = 0;
	cl_uint				temp_uint;
	cl_char*			device_string;
	size_t				device_string_length;
	cl_int				error;
	FILE*				pfile = NULL;

	// Get OpenCL platform, usually 1 per vendor
	error = clGetPlatformIDs(0, NULL, &platform_nn);

	if (verbose)
	{
		pfile = fopen(log_file, "a");
		fprintf(pfile, "Info: %d platform IDs found.\n", platform_nn);
		fclose(pfile);
	}

	platform_id = (cl_platform_id*) malloc (platform_nn * sizeof(cl_platform_id));

	error = clGetPlatformIDs(platform_nn, platform_id, NULL);

	if (error != CL_SUCCESS)
    {
        if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to get Platform ID! %d \n", error);
			fclose(pfile);
		}
		return(-3);
    }

	// Get the OpenCL device: use the first GPU device, or if none is available, the first CPU device
	// can be changed for testing purposes by changing CL_DEVICE_TYPE_GPU into CL_DEVICE_TYPE_CPU below:
	if(verbose){pfile = fopen(log_file, "a");}
	for (cl_uint index = 0; index < platform_nn; index++)
	{
		error = clGetPlatformInfo(platform_id[index], CL_PLATFORM_NAME, NULL, NULL, &device_string_length);
		device_string = (cl_char*) malloc (device_string_length * sizeof(cl_char));
		error = clGetPlatformInfo(platform_id[index], CL_PLATFORM_NAME, device_string_length, device_string, NULL);
		if(verbose){fprintf(pfile, "=== Platform %d: %s.\n", index+1, device_string);}
		free(device_string);
		// Check number of GPU devices
		error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_GPU, NULL, NULL, &temp_uint);
		gpu_nn += temp_uint;
		// Check number of CPU devices
		error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_CPU, NULL, NULL, &temp_uint);
		cpu_nn += temp_uint;
		// Get all devices
		error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_ALL, NULL, NULL, &temp_uint);
		device_list = (cl_device_id*) malloc (temp_uint * sizeof(cl_device_id));
		error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_ALL, temp_uint, device_list, NULL);
		for (cl_uint index2 = 0; index2 < temp_uint; index2++)
		{
			error = clGetDeviceInfo(device_list[index2], CL_DEVICE_NAME, NULL, NULL, &device_string_length);
			device_string = (cl_char*) malloc (device_string_length * sizeof(cl_char));
			error = clGetDeviceInfo(device_list[index2], CL_DEVICE_NAME, device_string_length, device_string, NULL);
			if(verbose){fprintf(pfile, "------- Device %d: %s.\n", index2+1, device_string);}
			free(device_string);
		}
		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				fprintf(pfile, "Error generating device overview! %d \n", error);
				fclose(pfile);
			}
			return(-4);
		}
	}
	if(verbose){fclose(pfile);}

	// Get the actual device id
	if (gpu_nn == 0 || force_cpu)
	{
		for (cl_uint index = 0; index < platform_nn; index++)
		{
			error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_CPU, 1, &device_id, NULL);
		}
	}
	else
	{
		for (cl_uint index = 0; index < platform_nn; index++)
		{
			error = clGetDeviceIDs(platform_id[index], CL_DEVICE_TYPE_GPU, 1, &device_id, NULL);
		}
	}

	if (error != CL_SUCCESS)
    {
        if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to get Device ID! %d \n", error);
			fclose(pfile);
		}
        return(-5);
    }


	// Check which device was selected for processing
	error = clGetDeviceInfo(device_id, CL_DEVICE_NAME, NULL, NULL, &device_string_length);
	device_string = (cl_char*) malloc (device_string_length * sizeof(cl_char));
	error = clGetDeviceInfo(device_id, CL_DEVICE_NAME, device_string_length, device_string, NULL);
	if (verbose)
	{
		pfile = fopen(log_file, "a");
		fprintf(pfile, "Info: using %s as compute device.\n", device_string);
		// fprintf(pfile, "Info: compile options: \n %s \n", compile_options);
		fclose(pfile);
	}
	free(device_string);

	// Get all device infor
	//error = clGetDeviceInfo(device_id, CL_DEVICE_LOCAL_MEM_SIZE, sizeof(cl_ulong), pthis_device_local_mem_size, NULL);
	//error = clGetDeviceInfo(device_id, CL_DEVICE_LOCAL_MEM_TYPE, sizeof(cl_device_local_mem_type), pthis_device_local_mem_type, NULL);
	//error = clGetDeviceInfo(device_id, CL_DEVICE_MAX_WORK_GROUP_SIZE, sizeof(size_t), pthis_device_max_work_group_size, NULL);
	//error = clGetDeviceInfo(device_id, CL_DEVICE_HOST_UNIFIED_MEMORY, sizeof(cl_bool), pthis_device_host_unified_memory, NULL);

	//if (verbose)
	//{
	//	pfile = fopen(log_file, "a");
	//	fprintf(pfile, "CL_DEVICE_LOCAL_MEM_SIZE:      %lu bytes\n", *pthis_device_local_mem_size);
	//	fprintf(pfile, "CL_DEVICE_LOCAL_MEM_TYPE:      %X \n", *pthis_device_local_mem_type);
	//	fprintf(pfile, "     1: CL_LOCAL\n");
	//	fprintf(pfile, "     2: CL_GLOBAL\n");
	//	fprintf(pfile, "CL_DEVICE_MAX_WORK_GROUP_SIZE: %d \n", *pthis_device_max_work_group_size);
	//	fprintf(pfile, "CL_DEVICE_HOST_UNIFIED_MEMORY: %d \n", *pthis_device_host_unified_memory);
	//	fclose(pfile);
	//}


	// Create context
	context = clCreateContext(0, 1, &device_id, NULL, NULL, &error);
    if (!context)
    {
        if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to create a compute context! %d \n", error);
			fclose(pfile);
		}
		return(-6);
    }
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Compute context created.\n");
			fclose(pfile);
		}
	}

	// Create command queue
	if(verbose)
	{
		*commands = clCreateCommandQueue(context, device_id, CL_QUEUE_PROFILING_ENABLE, &error);
	} else {
	    *commands = clCreateCommandQueue(context, device_id, 0, &error);
	}
		
	if (!commands)
    {
        if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to create a command queue! %d \n", error);
			fclose(pfile);
		}
		return(-7);
    }
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Command queue created.\n");
			fclose(pfile);
		}
	}

	return(0);

}

///////////////////////////////////////////////////////////////////////////////
// Execute the prepared OpenCL kernel.
//
int fExecuteKernel(cl_command_queue* commands, cl_kernel* kernel, cl_uint work_dim, size_t* global, size_t* local, cl_bool verbose, char* log_file)
{
	cl_int		error;
	cl_event	cmd_event;
	cl_ulong	cmd_queued;
	cl_ulong	cmd_submit;
	cl_ulong	cmd_start;
	cl_ulong	cmd_end;

	FILE*	pfile = NULL;

	error = clEnqueueNDRangeKernel(*commands, *kernel, work_dim, NULL, global, local, 0, NULL, &cmd_event);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to execute kernel! %d \n", error);
			fprintf(pfile, "Info: Global size: %u, %u, %u.\n", global[0], global[1], global[2]);
			fclose(pfile);
		}
	} else {
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Kernel is executing.\n");
			fprintf(pfile, "Info: Global size: %u, %u, %u.\n", global[0], global[1], global[2]);
			fclose(pfile);
		}
	}

	error = clFinish(*commands);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to finish! %d \n", error);
			fclose(pfile);
		}
	} else {
		if(verbose)
		{
			error = clGetEventProfilingInfo(cmd_event, CL_PROFILING_COMMAND_QUEUED, sizeof(cl_ulong), &cmd_queued, NULL);
			error = clGetEventProfilingInfo(cmd_event, CL_PROFILING_COMMAND_SUBMIT, sizeof(cl_ulong), &cmd_submit, NULL);
			error = clGetEventProfilingInfo(cmd_event, CL_PROFILING_COMMAND_START,  sizeof(cl_ulong), &cmd_start,  NULL);
			error = clGetEventProfilingInfo(cmd_event, CL_PROFILING_COMMAND_END,    sizeof(cl_ulong), &cmd_end,    NULL);

			pfile = fopen(log_file, "a");
			fprintf(pfile, "Kernel profile info.\n");
			fprintf(pfile, "Time queue to submit: %llu ns\n", cmd_submit - cmd_queued);
			fprintf(pfile, "Time submit to start: %llu ns\n", cmd_start  - cmd_submit);
			fprintf(pfile, "Time start to end:    %llu ns\n", cmd_end    - cmd_start );
			fclose(pfile);
		}
	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Read an existing OpenCL buffer.
//
int fReadBuffer(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_bool verbose, char* log_file)
{
	cl_int	error;
	FILE*	pfile = NULL;
	
	error = clEnqueueReadBuffer(*commands, *mem_ptr, CL_TRUE, 0, content_size, content, 0, NULL, NULL);
	
	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to read memory! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Data read from buffer.\n");
			fprintf(pfile, "Info: pixel 1024 is %f.\n", (float) ((float*)content)[1024]);
			fclose(pfile);
		}
	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Release an existing OpenCL buffer.
//
int fReleaseBuffer(cl_mem mem_ptr, cl_bool verbose, char* log_file)
{
	cl_int	error;
	FILE*	pfile = NULL;

	error = clReleaseMemObject(mem_ptr);
	
	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to release buffer! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Buffer released.\n");
			fclose(pfile);
		}
	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Release an existing OpenCL image.
//
int fReleaseImage(cl_mem mem_ptr, cl_bool verbose, char* log_file)
{
	cl_int	error;
	FILE*	pfile = NULL;

	error = clReleaseMemObject(mem_ptr);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to release image! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Image released.\n");
			fclose(pfile);
		}
	}

	return(0);
}

///////////////////////////////////////////////////////////////////////////////
// Release an existing OpenCL Command queue.
//
int fReleaseCommandQueue(cl_command_queue* commands, cl_bool verbose, char*	log_file)
{
	cl_context	context;
	cl_int		error;
	FILE*		pfile = NULL;

	// Get context
	error = clGetCommandQueueInfo(*commands, CL_QUEUE_CONTEXT, sizeof(cl_context), &context, NULL);
	
	if (error != 0)
    {
        if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to retreive the compute context! %d \n", error);
			fclose(pfile);
		}
		return(error);
    }
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Compute context retreived.\n");
			fclose(pfile);
		}
	}

	error = clReleaseCommandQueue(*commands);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to release command queue! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Command queue released.\n");
			fclose(pfile);
		}
	}

    error = clReleaseContext(context);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to release compute context! %d \n", error);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Compute context released.\n");
			fclose(pfile);
		}
	}


	return(0);

}

///////////////////////////////////////////////////////////////////////////////
// Release existing OpenCL programs and kernels
//
int fReleaseKernels(cl_kernel kernels[MAX_KERNELS], cl_int n_kernels, cl_bool verbose, char* log_file)
{

	int			error;
	cl_program	program[MAX_KERNELS];
	FILE*		pfile = NULL;

	for (int ii = 0; ii < n_kernels; ii++)
	{
		error = clGetKernelInfo(kernels[ii], CL_KERNEL_PROGRAM, sizeof(cl_program), &program[ii], NULL);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to retreive program nr. %d! Error: %d.\n", ii, error);
				fclose(pfile);
			}
		} else {
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Retreived program for kernel nr. %d.\n", ii);
				fclose(pfile);
			}

		}

		error = clReleaseKernel(kernels[ii]);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to release kernel nr. %d! %d \n", ii, error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Kernel nr. %d released.\n", ii);
				fclose(pfile);
			}
		}

		clReleaseProgram(program[ii]);

		if (error != CL_SUCCESS)
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Error: Failed to release compute program nr. %d! %d \n", ii, error);
				fclose(pfile);
			}
		}
		else
		{
			if (verbose)
			{
				pfile = fopen(log_file, "a");
				fprintf(pfile, "Info: Program nr. %d released.\n", ii);
				fclose(pfile);
			}
		}

	}

	return(0);

}

///////////////////////////////////////////////////////////////////////////////
// Set Kernel argument
//
int fSetKernelArg(cl_kernel kernel, cl_uint arg_index, cl_ulong arg_size, void* arg_value, cl_bool verbose, char* log_file)
{
	int			error;
	FILE*		pfile = NULL;

	error = clSetKernelArg(kernel, arg_index, arg_size, arg_value);

	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to set kernel argument! %d.\n", error);
			fclose(pfile);
		}
	} else {
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Kernel argument set.\n");
			fclose(pfile);
		}
	}

	return(0);

}

///////////////////////////////////////////////////////////////////////////////
// Write data to buffer
//
int fWriteBuffer(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_bool verbose, char* log_file)
{
	cl_int	error;
	FILE*	pfile = NULL;
	
	error = clEnqueueWriteBuffer(*commands, *mem_ptr, CL_TRUE, 0, content_size, content, 0, NULL, NULL);
	
	if (error != CL_SUCCESS)
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Error: Failed to write data to buffer! %d \n", error);
			fprintf(pfile, "Info: Content size (bytes): %llu.\n", content_size);
			fclose(pfile);
		}
	}
	else
	{
		if (verbose)
		{
			pfile = fopen(log_file, "a");
			fprintf(pfile, "Info: Data written to buffer.\n", error);
			fprintf(pfile, "Info: Content size (bytes): %llu.\n", content_size);
			fprintf(pfile, "Info: Pixel 1024 is %f.\n", ((float*)content)[1024]);
			fclose(pfile);
		}
	}

	return(0);
}