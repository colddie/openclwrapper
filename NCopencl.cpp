// NCproj_opencl.cpp : Contains all logic needed to call the openCL kernel functions.
//


#include "NCopencl.h"
#include "NCopencl_help.h"

// Global variables
cl_mem	buffers[MAX_BUFFERS];

///////////////////////////////////////////////////////////////////////////////
// Entry points for external calls.
//
DLL_EXPORT int fNCbuild_kernels(int argc, void *argv[])
{
	int 		result;
	cl_kernel*	kernel_ptr;

	if (argc != 8)
	{
		result = -1;
	} 
	else
	{

		kernel_ptr = (cl_kernel *) calloc (MAX_KERNELS, sizeof(cl_kernel));

		char* argv_7_ =  (*(idls *) argv[7]).s;

		result = fBuildKernels(	*(	cl_command_queue **)	argv[0],	// command queue
															kernel_ptr,	//
		//													kernels,	// kernels
								*(	cl_uint			  *)	argv[2],	// number of kernels
								 (	idls			  *)	argv[3],	// kernel file paths
								 (	idls			  *)	argv[4],	// kernel function names
								 (	idls			  *)	argv[5],	// compile options
								*(	cl_bool			  *)	argv[6],	// verbose
															argv_7_);	// log file

		// Return address to input parameter
		*(cl_kernel **) argv[1] = kernel_ptr;

	}

	return(result);

}

DLL_EXPORT int fNCcreate_buffer(int argc, void *argv[])
{
	int result;

	if (argc != 8)
	{
		result = -1;
	} 
	else
	{

		cl_mem*	argv_1_ = &buffers[*(cl_uint*) argv[1]];
		char*	argv_7_ = (*(idls *) argv[7]).s;

		//command_queue is a global variable defined above
		result = fCreateBuffer(	*(cl_command_queue **)	argv[0],	// command queue*
														argv_1_,	// cl_mem
								 (	void			*)	argv[2],	// content
								*(	cl_ulong		*)	argv[3],	// content_size
								*(	cl_int			*)	argv[4],	// read_write
								*(	cl_bool			*)	argv[5],	// use_host_ptr
								*(	cl_bool			*)	argv[6],	// verbose
														argv_7_);	// log_file

		// Return address to input parameter
		//*(cl_mem **) argv[1] = buffers;  
	}

	return(result);

}

DLL_EXPORT int fNCcreate_image(int argc, void *argv[])
{
	int result;

	if (argc != 10)
	{
		result = -1;
	} 
	else
	{

		cl_mem*	argv_1_ = &buffers[*(cl_uint*) argv[1]];
		char*	argv_9_ = (*(idls *) argv[9]).s;

		//command_queue is a global variable defined above
		result = fCreateImage(	*(cl_command_queue **)	argv[0],	// command queue*
														argv_1_,	// cl_mem
								 (	void			*)	argv[2],	// content
								//*(	cl_ulong		*)	argv[3],	// content_size
								*(cl_uint           *)  argv[3],     // image_width
								*(cl_uint           *)  argv[4],     // image_width
								*(cl_uint           *)  argv[5],     // image_width
								*(	cl_int			*)	argv[6],	// read_write
								*(	cl_bool			*)	argv[7],	// use_host_ptr
								*(	cl_bool			*)	argv[8],	// verbose
														argv_9_);	// log_file

		// Return address to input parameter
		//*(cl_mem **) argv[1] = buffers;  
	}

	return(result);

}

DLL_EXPORT int fNCcreate_command_queue(int argc, void *argv[])
{
	int					result;
	cl_command_queue*	cq_ptr; 
	
	if (argc != 4)
	{
		result = -1;
	} 
	else
	{

		cq_ptr = (cl_command_queue *) malloc (sizeof(cl_command_queue));
	
		char* argv_3_ = (*(idls *) argv[3]).s;

		//command_queue is a global variable defined above
		result = fCreateCommandQueue(				cq_ptr,		// command queue*
									 *(	cl_bool *)	argv[1],	// force_cpu
									 *(	cl_bool *)	argv[2],	// verbose
													argv_3_);	// log_file

		// Return address to input parameter
		*(cl_command_queue **) argv[0] = cq_ptr;

	}

	return(result);

}

DLL_EXPORT int fNCexecute_kernel(int argc, void *argv[])
{
	int			result;
	size_t		global[3];
	size_t		local[3];
	cl_uint4	temp4;

	if (argc != 8)
	{
		result = -1;
	}
	else
	{
		cl_command_queue*	argv_0_ = *(cl_command_queue **) argv[0];
		cl_kernel*			argv_1_ = *(cl_kernel **) argv[1];
		cl_kernel*			argv_2_ = &argv_1_[*(cl_uint *) argv[2]];
		cl_bool				argv_6_ = *(cl_bool *) argv[6];
		char*				argv_7_ = (*(idls *) argv[7]).s;

		//FILE* pfile = NULL;
		//pfile = fopen(argv_7_, "a");
		//fprintf(pfile, "Info: start of fExecuteKernel. \n");
		//fclose(pfile);

		temp4 = (*(cl_uint4 *) argv[4]);
		global[0] = temp4.s[0];
		global[1] = temp4.s[1];
		global[2] = temp4.s[2];

		if (*(cl_bool *) argv[3]) // use local?
		{
			temp4 = (*(cl_uint4 *) argv[5]);
			local[0] = temp4.s[0];
			local[1] = temp4.s[1];
			local[2] = temp4.s[2];
			
			result = fExecuteKernel(argv_0_,		// command queue
									argv_2_,		// kernel
									(cl_uint)(3),	// work dimension
									global,			// global size
									local,			// local size
									argv_6_,		// verbose
									argv_7_);		// log_file
		}
		else
		{
			result = fExecuteKernel(argv_0_,		// command queue
									argv_2_,		// kernel
									(cl_uint)(3),	// work dimension
									global,			// global size
									NULL,			// local size
									argv_6_,		// verbose
									argv_7_);		// log_file
		}

	}

	return(result);



}

DLL_EXPORT int fNCread_buffer(int argc, void *argv[])
{
	int result;

	if (argc != 6)
	{
		result = -1;
	} 
	else
	{

		cl_command_queue*	argv_0_ = *(cl_command_queue **) argv[0];
		cl_mem*				argv_1_ = &buffers[*(cl_uint *) argv[1]];
		void*				argv_2_ = argv[2];
		cl_ulong			argv_3_ = *(cl_ulong *) argv[3];
		cl_bool				argv_4_ = *(cl_bool *) argv[4];
		char*				argv_5_ = (*(idls *) argv[5]).s;

		//command_queue is a global variable defined above
		result = fReadBuffer(argv_0_,	// command queue*
							 argv_1_,	// cl_mem
							 argv_2_,	// data pointer
							 argv_3_,	// data size
							 argv_4_,	// verbose
							 argv_5_);	// log_file
	}

	return(result);
}

DLL_EXPORT int fNCread_image(int argc, void *argv[])
{

	return(1);

}

DLL_EXPORT int fNCrelease_buffer(int argc, void *argv[])
{
	int result;

	if (argc != 3)
	{
		result = -1;
	} 
	else
	{

		cl_mem	argv_0_ = buffers[*(cl_uint*) argv[0]];
		cl_bool	argv_1_ = *(cl_bool *) argv[1];
		char*	argv_2_ = (*(idls *) argv[2]).s;

		//command_queue is a global variable defined above
		result = fReleaseBuffer(argv_0_,	// cl_mem
								argv_1_,	// verbose
								argv_2_);	// log_file
	}

	return(result);

}

DLL_EXPORT int fNCrelease_image(int argc, void *argv[])
{
	int result;

	if (argc != 3)
	{
		result = -1;
	} 
	else
	{

		cl_mem	argv_0_ = buffers[*(cl_uint*) argv[0]];
		cl_bool	argv_1_ = *(cl_bool *) argv[1];
		char*	argv_2_ = (*(idls *) argv[2]).s;

		//command_queue is a global variable defined above
		result = fReleaseImage(argv_0_,	// cl_mem
			argv_1_,	// verbose
			argv_2_);	// log_file
	}

	return(result);
}

DLL_EXPORT int fNCrelease_command_queue(int argc, void *argv[])
{
	int result;

	if (argc != 3)
	{
		result = -1;
	}
	else
	{

		char* argv_2_ = (*(idls *) argv[2]).s;

		result = fReleaseCommandQueue(	*(	cl_command_queue **)	argv[0],	// command queue*
										*(	cl_bool			  *)	argv[1],	// verbose
																	argv_2_);	// log_file

	}

	return(result);

}

DLL_EXPORT int fNCrelease_kernels(int argc, void *argv[])
{
	int result;
			
	if (argc != 4)
	{
		result = -1;
	}
	else
	{

		char* argv_3_ = (*(idls *) argv[3]).s;

		//	*(cl_kernel **) argv[1] = kernels;
		result = fReleaseKernels(*(	cl_kernel **)	argv[0],	// kernels
								 *(	cl_uint	   *)	argv[1],	// n_kernels
								 *(	cl_bool	   *)	argv[2],	// verbose
													argv_3_);	// log_file

	}

	return(result);

}

DLL_EXPORT int fNCset_kernel_arg(int argc, void * argv[])
{
	int 		result;
	void* 		argv_4_;
	
	if (argc != 8)
	{
		result = -1;
	}
	else
	{
		cl_kernel*	argv_0_ = *(cl_kernel **) argv[0];
		cl_kernel	argv_1_ = argv_0_[*(cl_uint *) argv[1]];
		cl_uint		argv_2_ = *(cl_uint *) argv[2];
		cl_ulong	argv_3_ = *(cl_ulong *) argv[3];
		cl_bool		argv_6_ = *(cl_bool *) argv[6];
		char*		argv_7_ = (*(idls *) argv[7]).s;

		if (*(cl_bool *) argv[5]) // is argv[4] data or cl_mem
		{
			// cl_mem
			argv_4_ = (void *) &buffers[*(cl_uint *) argv[4]];
		}
		else
		{
			// data
			argv_4_ = (void *) argv[4];
		}	
		
		result = fSetKernelArg(argv_1_,	// kernel
							   argv_2_,	// arg_index
							   argv_3_,	// arg_size
							   argv_4_,	// arg_value (void*)
							   argv_6_,	// verbose
							   argv_7_);// log_file

	}

	return(result);

}

DLL_EXPORT int fNCunload(int argc, void *argv[])
{
	return(1);
}

DLL_EXPORT int fNCwrite_buffer(int argc, void *argv[])
{
	int result;

	if (argc != 6)
	{
		result = -1;
	} 
	else
	{
		cl_mem*	argv_1_ = &buffers[*(cl_uint*) argv[1]];
		char*	argv_5_ = (*(idls *) argv[5]).s;

		//command_queue is a global variable defined above
		result = fWriteBuffer(	*(cl_command_queue **)	argv[0],	// command queue*
														argv_1_,	// cl_mem*
								 (	void			*)	argv[2],	// content
								*(	cl_ulong		*)	argv[3],	// content_size
								*(	cl_bool			*)	argv[4],	// verbose
														argv_5_);	// log_file

		// Return address to input parameter
		//*(cl_mem **) argv[1] = buffers;  
	}

	return(result);



}

DLL_EXPORT int fNCwrite_image(int argc, void *argv[])
{

	return(1);
}