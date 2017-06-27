
char* oclLoadProgSource(const char* cFilename, const char* cPreamble, size_t* szFinalLength);
int fBuildKernels(cl_command_queue* commands, cl_kernel kernels[MAX_KERNELS], cl_ulong n_kernels, idls* file_paths, idls* function_names, idls* compile_options, cl_bool verbose, char* log_file);
int fCreateBuffer(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_int read_write, cl_bool use_host_ptr, cl_bool verbose, char* log_file);
int fCreateCommandQueue(cl_command_queue* commands, cl_bool force_cpu, cl_bool verbose, char* log_file);
int fExecuteKernel(cl_command_queue* commands, cl_kernel* kernel, cl_uint work_dim, size_t* global, size_t* local, cl_bool verbose, char* log_file);
int fReadBuffer(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_bool verbose, char* log_file);
int fReleaseBuffer(cl_mem mem_ptr, cl_bool verbose, char* log_file);
int fReleaseCommandQueue(cl_command_queue* commands, cl_bool verbose, char* log_file);
int fReleaseKernels(cl_kernel kernels[MAX_KERNELS], cl_int n_kernels, cl_bool verbose, char* log_file);
int fSetKernelArg(cl_kernel kernel, cl_uint arg_index, cl_ulong arg_size, void* arg_value, cl_bool verbose, char* log_file);
int fWriteBuffer(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_ulong content_size, cl_bool verbose, char* log_file);

int fCreateImage(cl_command_queue* commands, cl_mem* mem_ptr, void* content, cl_uint image_width, cl_uint image_height, cl_uint image_depth,  cl_int read_write, cl_bool use_host_ptr, cl_bool verbose, char* log_file);
int fReleaseImage(cl_mem mem_ptr, cl_bool verbose, char* log_file);