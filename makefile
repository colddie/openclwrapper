#== Original commands for compilation on Avalok.
#gcc -m64 -fPIC -c -I/opt/AMDAPP/include NCopencl.cpp -o ./NCopencl.lin64_o
#gcc -m64 -fPIC -c -I/opt/AMDAPP/include NCopencl_help.cpp -o ./NCopencl_help.lin64_o
#ld -G -o ./NCopencl_linux64.so NCopencl.lin64_o NCopencl_help.lin64_o /opt/AMDAPP/lib/x86_64/libOpenCL.so -lstdc++ -L./


# Declare the c_ required files
#==================================
C__SRCS =  NCopencl.cpp NCopencl_help.cpp

# Define objects and executables
#===============================
LIB_LINUX       = ../lib/NCopencl_wrapper_linux.so
LIB_LINUX64     = ../lib/NCopencl_wrapper_linux64.so
LIB_SOLARIS     = ../lib/NCopencl_wrapper_solaris.so
LIB_PC64SOLARIS = ../lib/NCopencl_wrapper_pc64solaris.so
C__OBJS_LIN     = $(C__SRCS:.cpp=.lin_o)
C__OBJS_LIN64   = $(C__SRCS:.cpp=.lin64_o)
C__OBJS_SOL     = $(C__SRCS:.cpp=.sol_o)
C__OBJS_PC64SOL = $(C__SRCS:.cpp=.pc64sol_o)

# User stuff
#===============
CDIR = ../..
USER_INCLUDE_DIRS = -I/opt/AMDAPP/include
USER_LIB_DIRS     = 
USER_LIBS_LINUX   = 
USER_LIBS_LINUX64 = /opt/AMDAPP/lib/x86_64/libOpenCL.so -l:libstdc++.so.6
USER_LIBS_SOLARIS = 

# System things
#==============
MATH_LIBS = -lm

# Options for compiler and linker
#================================
COMPILER_OPTIONS =  -O3
LINKER_OPTIONS   = 

# Declare compiler flags, select compiler
# Note that -fsingle does not exist for gcc.
# gcc returns doubles, never floats! Use /d_value in call_external
#=================================================================
C_FLAGS  = -fPIC -c
COMP     = gcc

#######################################################################
all:
	@echo
	@if [ "$(OS)" != "" ] ; \
          then make lib$(OS) ; \
	else \
          echo "OS type detected: "`uname` ;\
	  if [ `uname` = "SunOS" ] ; \
	      then make libsolaris ; \
	  elif [  `uname` = "Linux" ] ; \
	      then if [ `uname -m` = "x86_64" ] ; \
	             then echo '64 bit' ; make liblinux64 ; \
	             else echo '32 bit' ; make liblinux ; \
	           fi ; \
	  fi ;\
	fi

liblinux: $(C__OBJS_LIN)
	@echo linking $(LIB_LINUX)
	ld -G -o $(LIB_LINUX) $(C__OBJS_LIN) $(USER_LIB_DIRS) \
               $(USER_LIBS_LINUX)  $(MATH_LIBS) $(LINKER_OPTIONS)
	@echo 'Removing object files.'
	\rm *.lin_o
	@echo 'Done.'

liblinux64: $(C__OBJS_LIN64)
	@echo linking $(LIB_LINUX64)
	ld -G -o $(LIB_LINUX64) $(C__OBJS_LIN64) $(USER_LIB_DIRS) \
               $(USER_LIBS_LINUX64)  $(MATH_LIBS) $(LINKER_OPTIONS)
	@echo 'Removing object files.'
	\rm *.lin64_o
	@echo 'Done.'

libsolaris: $(C__OBJS_SOL)
	@echo linking $(LIB_SOLARIS)
	ld -G -o $(LIB_SOLARIS) $(C__OBJS_SOL) $(USER_LIB_DIRS) \
               $(USER_LIBS_SOLARIS)  $(MATH_LIBS) $(LINKER_OPTIONS)
	@echo 'Removing object files.'
	\rm *.sol_o
	@echo 'Done.'

libpc64solaris: $(C__OBJS_PC64SOL)
	@echo linking $(LIB_PC64SOLARIS)
	gcc -m64 -Bsymbolic -shared -fPIC -R/usr/sfw/lib/64 \
	-o $(LIB_PC64SOLARIS) $(C__OBJS_PC64SOL) $(USER_LIB_DIRS) \
               $(USER_LIBS_PC64SOLARIS)  $(MATH_LIBS) $(LINKER_OPTIONS)
	@echo 'Removing object files.'
	\rm *.pc64sol_o
	@echo 'Done.'

%.lin_o:%.cpp
	@echo Compiling $(@:.lin_o=.cpp)
	$(COMP) $(C_FLAGS) $(USER_INCLUDE_DIRS) $(COMPILER_OPTIONS) \
	   $(@:.lin_o=.cpp) -o $@
	@echo

%.lin64_o:%.cpp
	@echo Compiling $(@:.lin64_o=.cpp)
	$(COMP)  -m64 $(C_FLAGS) $(USER_INCLUDE_DIRS) $(COMPILER_OPTIONS) \
	   $(@:.lin64_o=.cpp) -o $@
	@echo

%.sol_o:%.cpp
	@echo Compiling $(@:.sol_o=.cpp)
	$(COMP) $(C_FLAGS) $(USER_INCLUDE_DIRS) $(COMPILER_OPTIONS) \
	   $(@:.sol_o=.cpp) -o $@
	@echo

%.pc64sol_o:%.cpp
	@echo Compiling $(@:.pc64sol_o=.cpp)
	$(COMP) -m64 -D__EXTENSIONS__ -fPIC -c \
	$(USER_INCLUDE_DIRS) $(COMPILER_OPTIONS) \
	   $(@:.pc64sol_o=.cpp) -o $@
	@echo

