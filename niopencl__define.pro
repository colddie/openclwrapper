;+
; Force the log file under current directory
; line 54, identify path seperator
; NAME:
;    NIopencl__define
;
; PURPOSE:
;    This object provides a link to opencl functionality in IDL.
;    Functions in the object list which opencl functions they link to.
;
; CATEGORY:
;    utility library
;
; COMMON BLOCKS:
;    NC_lib_common
;
; SIDE EFFECTS:
;    unknown
;
; RESTRICTIONS:
;    Only available for win64 / linux64 with opencl drivers installed
;
; PROCEDURE:
;    Links to NCopencl_wrapper_linux64.so / NCopencl_wrapper.dll
;
; EXAMPLE:
;    see implementation in NIdef_proj_cbct_pm_ocl.pro and 
;    NIproj_cbct_pm_ocl.pro
;
; MODIFICATION HISTORY:
; 	Written by: Koen Michielsen, oct/2013
;-

function niopencl::init
;+
; This function is called when an object of type 'niopencl'
; is created. It initializes internal variables.
;-

  common NC_lib_common ;->  NC_opencl_wrapper
 ; if NC_opencl_wrapper eq '' then begin    ;or NC_opencl_wrapper eq NULL
 ;   if !version.os eq 'Win32_64' then  NC_opencl_wrapper='\\uz\data\Admin\Hermes\Soft\procnew\RESNEW\RECONSTRUCTION\idl\win64\opencl_wrapper\x64\Release\opencl_wrapper.dll'
;if !version.os eq 'Linux64' then  NC_opencl_wrapper='/uz/data/Admin/Hermes/Soft/procnew/RESNEW/idl/recon/lib/NCopencl_wrapper_linux64.so'
 ; endif
  CD, CURRENT=curDir
  
  ;NC_opencl_wrapper = '\\uz\data\Admin\ngeresearch\taosun\code\opencl\workspace\opencl_wrapper\x64\Release\opencl_wrapper.dll'
  
  self.verbose       = ptr_new(/allocate)
  self.force_cpu     = ptr_new(/allocate)
  self.nc_ocl_lib    = ptr_new(/allocate)
  self.nc_ocl_log    = ptr_new(/allocate)
  self.kernel_names  = ptr_new(/allocate)
  self.command_queue = 0ULL
  self.kernel_list   = 0ULL
  self.buffer_list   = 0ULL

  *(self.verbose)      = 1L ; set true to enable log
  *(self.force_cpu)    = 0L
  *(self.nc_ocl_lib)   = NC_opencl_wrapper
  *(self.nc_ocl_log)   = curDir + path_sep() +'log.txt' ; nge() + 'opencl.log'
  *(self.kernel_names) = ''
;  stop
  return, 1

end

pro niopencl::cleanup
;+
; Mandatory cleanup procedure:
; Free all pointers and call cleanup method in parent classes
;-

  b = self->unload()
  b = self->release_kernels()
  b = self->release_command_queue()

  ptr_free, self.verbose
  ptr_free, self.force_cpu
  ptr_free, self.nc_ocl_lib
  ptr_free, self.nc_ocl_log
  ptr_free, self.kernel_names

end

function niopencl::get_ptr, rawVar
;+
; Implementation of the object getter, returns a pointer.
;-

  var = strlowcase(rawVar)

  case var of
     'verbose'       : return, self.verbose
     'force_cpu'     : return, self.foce_cpu
     'nc_ocl_lib'    : return, self.nc_ocl_lib
     'nc_ocl_log'    : return, self.nc_ocl_log
     'command_queue' : return, self.command_queue
     'kernel_list'   : return, self.kernel_list
     'kernel_names'  : return, self.kernel_names

     else : return, 0

  endcase

end

function niopencl::set_ptr, rawVar, ptr
;+
; Implementation of the object setter
;
; *** WARNING ***
; Many variables are interdependant, so be  very careful 
; when implementing any changes: always adjust ALL dependant variables
;-

  var = strlowcase(rawVar)

  case var of
     'verbose'       : self.verbose       = ptr
     'force_cpu'     : self.force_cpu     = ptr
     'nc_ocl_lib'    : self.nc_ocl_lib    = ptr
     'nc_ocl_log'    : self.nc_ocl_log    = ptr
     'command_queue' : self.command_queue = ptr
     'kernel_list'   : self.kernel_list   = ptr
     'kernel_names'  : self.kernel_names  = ptr

     else : return, 0

  endcase

  return, 1

end

function niopencl::create_command_queue
;+
; Create an OpenCL command queue for one device
; 
; clGetPlatformIDs
; clGetDeviceIDs
; clCreateContext
; clCreateCommandQueue
;-

  command_queue_ptr = 0ULL

  b = call_external(*(self.nc_ocl_lib),        $  
                    'fNCcreate_command_queue', $
                    command_queue_ptr,         $
                    *(self.force_cpu),         $
                    *(self.verbose),           $
                    *(self.nc_ocl_log)         )

  self.command_queue = command_queue_ptr

  return, b

end

function niopencl::release_command_queue
;+
; Release the current command queue & context
;
; clReleaseCommandQueue
; clReleaseContext
;-

  b = call_external(*(self.nc_ocl_lib),         $
                    'fNCrelease_command_queue', $
                    self.command_queue,         $
                    *(self.verbose),            $
                    *(self.nc_ocl_log)          )

  self.command_queue = 0LL

  return, b

end

function niopencl::build_kernels, file_paths,     $
                                  function_names, $
                                  idl_call_names, $
                                  compile_options
;+
; Build a list of kernels for the current command queue
;
; oclLoadProgSource
; clCreateProgramWithSource
; clBuildProgram
; clCreateKernel
;-

  kernel_list_ptr = 0ULL
  *(self.kernel_names) = idl_call_names

  n_kernels = ulong(n_elements(file_paths))
  if n_elements(idl_call_names)  NE n_kernels then print, 'Error'
  if n_elements(function_names)  NE n_kernels then print, 'Error'
  if n_elements(compile_options) NE n_kernels then print, 'Error'

  b = call_external(*(self.nc_ocl_lib), $
                    'fNCbuild_kernels', $
                    self.command_queue, $
                    kernel_list_ptr,    $
                    n_kernels,          $
                    file_paths,         $
                    function_names,     $
                    compile_options,    $
                    *(self.verbose),    $
                    *(self.nc_ocl_log)  )

  self.kernel_list = kernel_list_ptr

  return, b

end

function niopencl::release_kernels
;+
; Release the current list of kernels
;
; clReleaseKernel
; clReleaseProgram
;-

  n_kernels = ulong(n_elements(*(self.kernel_names)))

  b = call_external(*(self.nc_ocl_lib),   $
                    'fNCrelease_kernels', $
                    self.kernel_list,     $
                    n_kernels,            $
                    *(self.verbose),      $
                    *(self.nc_ocl_log)    )

  self.kernel_list = 0ULL

  return, b

end

function niopencl::create_buffer, mem_ptr, content, read_write, use_host_ptr
;+
; Create and fill OpenCL buffer
;
; clCreateBuffer
; clEnqueueWriteBuffer
;
; read_write:
;  - 0 : read_write
;  - 1 : write_only
;  - 2 : read_only
;
; use_host_ptr: 0/1 (false/true)
;-

  case size(content, /type) of
     1    : var_size = 1ULL ; byte
     2    : var_size = 2ULL ; int     - short
     3    : var_size = 4ULL ; long    - int
     4    : var_size = 4ULL ; float
     5    : var_size = 8ULL ; double
     12   : var_size = 2ULL ; uint    - ushort
     13   : var_size = 4ULL ; ulong   - uint
     14   : var_size = 8ULL ; long64  - long
     15   : var_size = 8ULL ; ulong64 - ulong
     else : var_size = 0ULL
  endcase

  content_size = n_elements(content) * var_size

  if content_size EQ 0 then begin
     print, 'Variable size could not be determined.'
     stop
  endif

  b = call_external(*(self.nc_ocl_lib),   $
                    'fNCcreate_buffer',   $
                    self.command_queue,   $
                    ulong(mem_ptr),       $
                    content,              $
                    content_size,         $
                    long(read_write),     $
                    long(use_host_ptr),   $
                    *(self.verbose),      $
                    *(self.nc_ocl_log)    )

  return, b

end

; ---------------------
function niopencl::create_image, mem_ptr, content, image_width, image_height, image_depth, read_write, use_host_ptr
;+
; Create and fill OpenCL image
;
; clCreateImage
; clEnqueueWriteImage
;
; read_write:
;  - 0 : read_write
;  - 1 : write_only
;  - 2 : read_only
;
; use_host_ptr: 0/1 (false/true)
;-

  case size(content, /type) of
     1    : var_size = 1ULL ; byte
     2    : var_size = 2ULL ; int     - short
     3    : var_size = 4ULL ; long    - int
     4    : var_size = 4ULL ; float
     5    : var_size = 8ULL ; double
     12   : var_size = 2ULL ; uint    - ushort
     13   : var_size = 4ULL ; ulong   - uint
     14   : var_size = 8ULL ; long64  - long
     15   : var_size = 8ULL ; ulong64 - ulong
     else : var_size = 0ULL
  endcase

  ;content_size = n_elements(content) * var_size

  ;if content_size EQ 0 then begin
  ;   print, 'Variable size could not be determined.'
  ;   stop
  ;endif

  b = call_external(*(self.nc_ocl_lib),   $
                    'fNCcreate_image',   $
                    self.command_queue,   $
                    ulong(mem_ptr),       $
                    content,              $
                    ;content_size,         $
					image_width,    $
					image_height,    $
					image_depth,    $
                    long(read_write),     $
                    long(use_host_ptr),   $
                    *(self.verbose),      $
                    *(self.nc_ocl_log)    )

  return, b

end



function niopencl::write_buffer, mem_ptr, content
;+
; Write data to buffer
;
; clEnqueueWriteBuffer
;-

  case size(content, /type) of
     1    : var_size = 1ULL ; byte
     2    : var_size = 2ULL ; int     - short
     3    : var_size = 4ULL ; long    - int
     4    : var_size = 4ULL ; float
     5    : var_size = 8ULL ; double
     12   : var_size = 2ULL ; uint    - ushort
     13   : var_size = 4ULL ; ulong   - uint
     14   : var_size = 8ULL ; long64  - long
     15   : var_size = 8ULL ; ulong64 - ulong
     else : var_size = 0ULL
  endcase

  content_size = n_elements(content) * var_size

  if content_size EQ 0 then begin
     print, 'Variable size could not be determined.'
     stop
  endif

  b = call_external(*(self.nc_ocl_lib), $
                    'fNCwrite_buffer',  $
                    self.command_queue, $
                    ulong(mem_ptr),     $
                    content,            $
                    content_size,       $
                    *(self.verbose),    $
                    *(self.nc_ocl_log)  )

  return, b

end

function niopencl::read_buffer, mem_ptr, content
;+
; Read data from buffer to content
;
; clEnqueueReadBuffer
;-

  case size(content, /type) of
     1    : var_size = 1ULL ; byte
     2    : var_size = 2ULL ; int     - short
     3    : var_size = 4ULL ; long    - int
     4    : var_size = 4ULL ; float
     5    : var_size = 8ULL ; double
     12   : var_size = 2ULL ; uint    - ushort
     13   : var_size = 4ULL ; ulong   - uint
     14   : var_size = 8ULL ; long64  - long
     15   : var_size = 8ULL ; ulong64 - ulong
     else : var_size = 0ULL
  endcase

  content_size = n_elements(content) * var_size

  if content_size EQ 0 then begin
     print, 'Variable size could not be determined.'
     stop
  endif

  b = call_external(*(self.nc_ocl_lib),  $
                    'fNCread_buffer',    $
                    self.command_queue,  $
                    ulong(mem_ptr),      $
                    content,             $
                    content_size,        $
                    *(self.verbose),     $
                    *(self.nc_ocl_log)   )

  return, b

end

function niopencl::release_buffer, mem_ptr
;+
; Release buffer
;
; clReleaseMemObject
;-

  b = call_external(*(self.nc_ocl_lib),  $
                    'fNCrelease_buffer', $
                    ulong(mem_ptr),      $
                    *(self.verbose),     $
                    *(self.nc_ocl_log)   )

  return, b

end

; ---------------------
function niopencl::release_image, mem_ptr
;+
; Release image
;
; clReleaseMemObject
;-

  b = call_external(*(self.nc_ocl_lib),  $
                    'fNCrelease_image', $
                    ulong(mem_ptr),      $
                    *(self.verbose),     $
                    *(self.nc_ocl_log)   )

  return, b

end



function niopencl::set_kernel_arg, kernel, arg_index, arg_value, mem_ptr
;+
; Set kernel arguments
;
; clSetKernelArg
;-

  for ii = 0, n_elements(*(self.kernel_names))-1 do begin
     if kernel EQ (*(self.kernel_names))[ii] then begin
        kernel_index = ulong(ii)
        break
     endif
  endfor

  if mem_ptr then begin
     arg_size  = 8ULL ; cl_mem
     arg_value = ulong(arg_value)
  endif else begin
     case size(arg_value, /type) of
        1    : var_size = 1ULL  ; byte
        2    : var_size = 2ULL  ; int     - short
        3    : var_size = 4ULL  ; long    - int
        4    : var_size = 4ULL  ; float
        5    : var_size = 8ULL  ; double
        12   : var_size = 2ULL  ; uint    - ushort
        13   : var_size = 4ULL  ; ulong   - uint
        14   : var_size = 8ULL  ; long64  - long
        15   : var_size = 8ULL  ; ulong64 - ulong
        else : var_size = 0ULL
     endcase
     arg_size = n_elements(arg_value) * var_size
  endelse

  b = call_external(*(self.nc_ocl_lib),  $
                    'fNCset_kernel_arg', $
                    self.kernel_list,    $
                    kernel_index,        $
                    ulong(arg_index),    $
                    ulong64(arg_size),   $
                    arg_value,           $
                    ulong(mem_ptr),      $
                    *(self.verbose),     $
                    *(self.nc_ocl_log)   )

  return, b

end

function niopencl::execute_kernel, kernel, global, local, use_local
;+
; Execute kernel
;
; clEnqueueNDRangeKernel
; clFinish
; clGetEventProfilingInfo (if verbose = 1)
;-

  for ii = 0, n_elements(*(self.kernel_names))-1 do begin
     if kernel EQ (*(self.kernel_names))[ii] then begin
        kernel_index = ulong(ii)
        break
     endif
  endfor

  b = call_external(*(self.nc_ocl_lib),  $
                    'fNCexecute_kernel', $
                    self.command_queue,  $
                    self.kernel_list,    $
                    kernel_index,        $
                    ulong(use_local),    $
                    ulong(global),       $
                    ulong(local),        $
                    *(self.verbose),     $
                    *(self.nc_ocl_log)   )

  return, b

end

function niopencl::unload
;+
; Unload library after call
;-

  b = call_external(*(self.nc_ocl_lib), $
                    'fNCunload',        $
                    *(self.verbose),    $
                    /unload             )

  return, b

end

pro niopencl__define

  struct = {niopencl,                 $
            verbose       : ptr_new(),$
            force_cpu     : ptr_new(),$
            nc_ocl_lib    : ptr_new(),$
            nc_ocl_log    : ptr_new(),$
            kernel_names  : ptr_new(),$
            command_queue : 0ULL,     $
            kernel_list   : 0ULL,     $
            buffer_list   : 0ULL      }

  return

end
