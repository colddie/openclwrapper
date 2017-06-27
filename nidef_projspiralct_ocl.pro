;+
; line 268, DefinitionAS has a negative anode angle
; voxel offset is defined implicitly
; update to the same version of nidef_projdistdspiralct.pro
; NAME:
;    NIdef_projdistdspiralct
;
; PURPOSE:
;    Define a (back)projector for a helical CT scan, and in particular
;    for our Siemens CT systems.
;    (Currently only for Sensation 16, extension should be easy.)
;
; CATEGORY:
;    Reconstruction
;
; CALLING SEQUENCE:
;    projdescrip = NIdef_projdistdspiralct(tubeangle, tablepos, alignment, $
;                                          ncols, nrows, nplanes, $
;                                          pixelsizemm, planesepmm, $
;                                          ctmodel = ctmodel)
;
; INPUTS:
;    TUBEANGLE : array of NRANGLES elements with the tube angles, as
;                produced by NIread_bio16 and similar routines.
;
;    TABLEPOS : array of NRANGLES x NRCTSLICES with the table
;               positions for each view and each detector ring.
;               See NIread_bio16_ct and similar.
;
;    ALIGNMENT : array with detector offsets, e.g. the alternating
;                1/8 detector offset for improved sampling.  See
;                NIread_bio16_ct.
;
;    NCOLS
;    NROWS
;    NPLANES:  dimensions of the reconstruction image.
;
;    PIXELSIZEMM : transaxial pixel size of the reconstruction image.
;
;    PLANESEPMM: axial pixel size of the reconstruction image.
;
; OPTIONAL INPUTS:
;    none
;	
; KEYWORD PARAMETERS:
;    CTMODEL : currently only '16' for Sensation 16. MANDATORY keyword!
;              To be extended...
;
;    DET_REBIN : number of detector bins to be summed to reduce the
;                size of the sinogram. Default is 1, i.e. no size reduction.
;
;    ANGLE_REBIN : number of angles to be summed for reducing the
;                size of the sinogram. Default is 1, i.e. no summing.
;
;    COLOFFSET : shift of the center of the reconstruction image
;                in col direction, in mm.
;
;    ROWOFFSET : shift of the center of the reconstruction image
;                in row direction, in mm.
;
;    IMGPLANE0: table position (mm) of the first plane to be
;               reconstructed. Default is such that the central table
;               position of the helical scan corresponds to the center
;               of the reconstruction volume.
;
;    RIGMOTION : either scalar (= no motion), or an array of 6 x
;               NRVIEWS, containing the rigid motion that must be
;               compensated during reconstruction.
;               See NIdistd_proj3d_1angle for details.
;
;    FLYINGFOCUS: receives 1 if the CT used flying focal spot to
;               increase the sampling in the transaxial plane, and 0
;               if this was not the case. This is deduced from
;               ALIGNMENT, which is all zeros when no flying focal
;               spot is used.
;
;    RAYTRACING : by default, the distance driven (back)projector is
;               used. When RAYTRACING is set, the ray tracing (back)
;               projector is used (Joseph method). This is detector
;               based, producing decent projections. The
;               backprojection is the exact transpose, but it looks a
;               bit ugly. But that should not matter too much for
;               iterative reconstruction.
;
; OUTPUTS:
;    PROJDESCRIP : a structure, ready to be used by NIproj (which will
;                  call NIproj_distd_spiralct to do the job).
;
; OPTIONAL OUTPUTS:
;    none
;
; COMMON BLOCKS:
;    none
;
; SIDE EFFECTS:
;    none
;
; RESTRICTIONS:
;    Currently only for Sensation 16, represented by ctmodel = '16'.
;
; PROCEDURE:
;    
;
; EXAMPLE:
;    
;
; SEE ALSO:
;    NIproj_distd_spiralct, NIdistd_proj3d_1angle
;
; MODIFICATION HISTORY:
; 	Written by:	Johan Nuyts, 2010.
;       june 2012 or so: added FLYINGFOCUS
;       aug 2012, JN: added RAYTRACING
;
;       dec 2012: JN, implementation of projector for Definition AS,
;       based on
;        TG Flohr, K Stierstorfer et al, "Image reconstruction and
;        image quality evaluation for a 64-slice CT scanner with
;        flying focal spot", Med Phys 2005; 32 (8): 2536-2547.
;-

compile_opt strictarrsubs

function NIdef_projspiralct_ocl, tubeangle, tablepos, alignment, $
                                  ncols, nrows, nplanes,          $
                                  pixelsizemm, planesepmm,        $
                                  zalignment  = zalignment, $
                                  det_rebin   = det_rebin,        $
                                  angle_rebin = angle_rebin,      $
                                  ctmodel     = ctmodel,          $
                                  coloffset   = coloffset,        $
                                  rowoffset   = rowoffset,        $
								  planeoffset  = planeoffset,       $
                                  imgcol0     = imgcol0,          $
                                  imgrow0     = imgrow0,          $
                                  imgplane0   = imgplane0,        $
                                  rigmotion   = rigmotion,        $
                                  trim        = trim,             $     ;
                                  reorder     = reorder,          $     ;
                                  flyingfocus = flyingfocus, $
                                  raytracing  = raytracing, $
                                  volumefwhm  = volumefwhm, $
								  fwhm        = fwhm,      $
                                  scale_fac   = scale_fac,  $
                                  scale_det   = scale_det,  $
								  fast_math = fast_math,   $
                                  force_cpu = force_cpu,   $
                                  detbins   = detbins, $
                                  srclocs   = srclocs, $
                                  flat = flat,  $
                                  parse_initial = parse_initial, $
                                  opt_mem = opt_mem, $
                                  ;vox_offset = vox_offset, $
                                  ;initial_coords = initial_coords, $
								  kernel_path = kernel_path, $
                                  supsample   = supsample, $
								  smallbin    = smallbin, $
								  nonrigmotion = nonrigmotion



common NIfiles 
;case StrUpCase(!Version.OS) OF
;'WIN32':  NIpath_kernels = '\\uz\data\Admin\ngeresearch\taosun\code\opencl\'  + path_sep()
;'LINUX':  NIpath_kernels = '/uz/data/Admin/ngeresearch/taosun/code/opencl'  + path_sep()
;endcase
NIpath_kernels = kernel_path
log_file = kernel_path + 'log.txt'   ; deprecated

if n_elements(ctmodel)     eq 0 then ctmodel = '16'
if n_elements(det_rebin)   eq 0 then det_rebin = 1
if n_elements(angle_rebin) eq 0 then angle_rebin = 1
if n_elements(rigmotion)   eq 0 then rigmotion = 0.0
if n_elements(volumefwhm)  eq 0 then volumefwhm = 0.0
if n_elements(fwhm)        eq 0 then fwhm = 0.0
if n_elements(coloffset) eq 0 then coloffset = 0.0
if n_elements(rowoffset) eq 0 then rowoffset = 0.0
if n_elements(planeoffset) eq 0 then planeoffset = 0.0
if keyword_set(supsample) or keyword_set(smallbin) then begin 
  factor = 2
endif else factor = 1

case ctmodel of 
  '16' : begin
    ;detpixsizemm   = 1.40830 / factor
    ;fpixelsizemm   = detpixsizemm * det_rebin
    focus2centermm = 570.0
    focus2detector = 1040.0
    nchannels      = 672 / det_rebin  * factor
    radiusmm       = focus2centermm
    fanangle       = 2 * !pi * 672. / 4640.0 ; from Karl Stierstorfer
    flyingfocus    = max(alignment) ne 0
    fanangle_inc   = fanangle / 672.0
    detpixsizemm   = fanangle_inc * focus2detector  / factor
    fpixelsizemm   = detpixsizemm * det_rebin
    ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 672.0 * det_rebin
	
    ndetplanes = (size(tablepos))[2]
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
    ;pfpixelsizemm = 0           ; need to update

    ; center of rotation offset in number of detectors 
    ;- - 
     if flyingfocus eq 0   $
      then fan_coroffset = 1.25 / det_rebin $ ;no flying focal spot    ;(1.25-0.125)
      else fan_coroffset = 1.125 / det_rebin ;flying focal spot

	if flyingfocus eq 0 and factor eq 2 then $         ;
        fan_coroffset = 1.125/ det_rebin * 2
		
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse
  end

  '16t' : begin
    ;detpixsizemm   = 1.40830 /  factor
    ;fpixelsizemm   = detpixsizemm * det_rebin
    focus2centermm = 570.0
    focus2detector = 1040.0
    nchannels      = 160. / det_rebin   * factor                         ; 140
    radiusmm       = focus2centermm
    fanangle       = 2 * !pi * 160. / 4640.0 ; from Karl Stierstorfer
    fanangle_inc   = fanangle / 672.0
    detpixsizemm   = fanangle_inc * focus2detector  / factor
    fpixelsizemm   = detpixsizemm * det_rebin
    ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 140.0 * det_rebin
	
	flyingfocus    = max(alignment) ne 0
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
    
    ndetplanes = (size(tablepos))[2]
    ; center of rotation offset in number of detectors 
    ;- - 
     if flyingfocus eq 0  $
      then fan_coroffset = 1.25 / det_rebin $ ;no flying focal spot
      else fan_coroffset = 1.125 / det_rebin ;flying focal spot

	if flyingfocus eq 0 and factor eq 2 then $         ;
        fan_coroffset = 1.125/ det_rebin * 2
		
    zffs = 0
  end
  
  
  '16e' : begin
    focus2centermm = 535.0
    focus2detector = 940.0
    nchannels      = 736 / det_rebin  * factor
    radiusmm       = focus2centermm
    fanangle       = 0.973894
    fanangle_inc   = fanangle / 736.0
    detpixsizemm   = fanangle_inc * focus2detector  / factor
	fpixelsizemm   = detpixsizemm * det_rebin
    flyingfocus    = max(alignment) ne 0

    ndetplanes = (size(tablepos))[2]
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
	
    ; center of rotation offset in number of detectors 
    ;- - 
     if flyingfocus eq 0  $                   ; Emotion 16 always have flyingfocus on
      then fan_coroffset = (1.25-3.5) / det_rebin $ ;no flying focal spot            ; was -(1.25+0.75)
      else fan_coroffset = (1.125-3.25) / det_rebin ;flying focal spot              ; not sure why no quarter-shift ; was -(1.125+0.875)

	if flyingfocus eq 0 and factor eq 2 then $         ;
        fan_coroffset = (1.125-3.25)/ det_rebin * 2
		
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse
  end

  '40' : begin
    ; 25 july 2014: I found better agreement with the data with a negative
    ; anode angle here! To be checked for the Definition as well!
    ;=====================================================================
    ;fpixelsizemm   = 1.40830 * det_rebin
    focus2centermm = 570.0
    focus2detector = 1040.0
    nchannels      = 672 / det_rebin
    radiusmm       = focus2centermm
    fanangle       = 2 * !pi * 672. / 4640.0 ; from Karl Stierstorfer
    flyingfocus    = max(alignment) ne 0
    fanangle_inc   = fanangle / 672.0
    detpixsizemm   = fanangle_inc * focus2detector
    fpixelsizemm   = detpixsizemm * det_rebin
    ndetplanes = (size(tablepos))[2]
    ; center of rotation offset in number of detectors 
                                ;- - 
    anodeangle = - 8.0 * !pi / 180.0   ;anode angle is between 7 and 9 degrees
    align_mm       = alignment * detpixsizemm

    if flyingfocus eq 0 $
      then fan_coroffset = 1.25 / det_rebin $ ;no flying focal spot
    else fan_coroffset = 1.125 / det_rebin ;flying focal spot
    
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse

  end

  '64' : begin
      focus2centermm = 570.0
      focus2detector = 1040.0
	  nchannels      = 672 / det_rebin  * factor
      fanangle       = 2 * !pi * 672. / 4640.0 ; from Karl Stierstorfer, PROBABLY
      fanangle_inc   = fanangle / 672.0
      detpixsizemm   = fanangle_inc * focus2detector  / factor
      fpixelsizemm   = detpixsizemm * det_rebin
      ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 736.0 * det_rebin
      
      ndetplanes = (size(tablepos))[2]
      ; center of rotation offset in number of detectors 
                                ;- - 
      anodeangle = 8.0 * !pi / 180.0   ;anode angle is between 7 and 9 degrees, NEED TO BE CHECKED!
      align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)

	 flyingfocus    = max(alignment) ne 0
     if flyingfocus eq 0  $
        then fan_coroffset = 1.25 / det_rebin $ ;no flying focal spot
      else fan_coroffset = 1.125 / det_rebin ;flying focal spot
    
	  if flyingfocus eq 0 and factor eq 2 then $         ;
        fan_coroffset = 1.125/ det_rebin * 2
	  
      if n_elements(zalignment) eq 0 then begin
        zffs = 0
      endif else begin
        zffs = max(abs(zalignment)) ne 0
      endelse
  end
  
  
  'DefinitionAS' : begin
    fanangle_inc   = 0.067864004196156 * !pi / 180.0
    focus2centermm = 595.0
    focus2detector = 1085.0
    nchannels      = 736 / det_rebin * factor
    radiusmm       = focus2centermm
    fanangle       = fanangle_inc * 736.0                      ; 49.9479
    detpixsizemm   = fanangle_inc * focus2detector / factor
    fpixelsizemm   = detpixsizemm * det_rebin
    ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 736.0 * det_rebin
	
    anodeangle = -8.0 * !pi / 180.0   ;anode angle is between 7 and 9 degrees

    ndetplanes = (size(tablepos))[2]
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
    ; channel center (with channel 1 at the right side of the detector
    ; if tube is in 12 o'clock position):
    ;  normal mode 367.25
    ;  FFS mode    367.625 (odd)
    ;              367.125 (even)
    if n_elements(flyingfocus) eq 0 $
      then flyingfocus    = max(alignment) ne 0
    if flyingfocus eq 0  $
      then fan_coroffset = (1.25) / det_rebin $ ;no flying focal spot  mct 0.25? flash 0.5
      else fan_coroffset = (1.125) / det_rebin ;flying focal spot      mct 0.125? flash 0.25

    if flyingfocus eq 0 and factor eq 2 then $         ;
      fan_coroffset = (1.125) / det_rebin * 2
	  
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse
  end

  'DefinitionASt' : begin
    fanangle_inc   = 0.067864004196156 * !pi / 180.0
    focus2centermm = 595.0
    focus2detector = 1085.0
    nchannels      = 736 / det_rebin * factor /2
    radiusmm       = focus2centermm
    fanangle       = fanangle_inc * 736.0 /2                     ; 49.9479
    detpixsizemm   = fanangle_inc * focus2detector / factor
    fpixelsizemm   = detpixsizemm * det_rebin
    ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 736.0 * det_rebin
	
    anodeangle = -8.0 * !pi / 180.0   ;anode angle is between 7 and 9 degrees

    ndetplanes = (size(tablepos))[2]
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
    ; channel center (with channel 1 at the right side of the detector
    ; if tube is in 12 o'clock position):
    ;  normal mode 367.25
    ;  FFS mode    367.625 (odd)
    ;              367.125 (even)
    if n_elements(flyingfocus) eq 0 $
      then flyingfocus    = max(alignment) ne 0
    if flyingfocus eq 0  $
      then fan_coroffset = (1.25) / det_rebin $ ;no flying focal spot  mct 0.25? flash 0.5
      else fan_coroffset = (1.125) / det_rebin ;flying focal spot      mct 0.125? flash 0.25

    if flyingfocus eq 0 and factor eq 2 then $         ;
      fan_coroffset = (1.125) / det_rebin * 2
	  
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse
  end
  
  'DefinitionASplus' : begin
	
	
   end

  'Force' : begin
    fanangle       = 50.0 / 180.0 * !pi                  ; system B 34.75
    fanangle_inc   = fanangle / 920.0
    focus2centermm = 595.0
    focus2detector = 1085.6
    nchannels      = 920 / det_rebin * factor
    radiusmm       = focus2centermm
    detpixsizemm   = fanangle_inc * focus2detector / factor
    fpixelsizemm   = detpixsizemm * det_rebin
    ;pfpixelsizemm  = 2 * sin(fanangle/2) * focus2detector / 920.0 * det_rebin

    anodeangle = 8.0 * !pi / 180.0   ;anode angle is between 7 and 9 degrees       ?? negative

    ndetplanes = (size(tablepos))[2]
    align_mm       = alignment * detpixsizemm * focus2centermm / (focus2detector-focus2centermm)
    ; channel center (with channel 1 at the right side of the detector
    ; if tube is in 12 o'clock position):
    ;  normal mode 367.25
    ;  FFS mode    367.625 (odd)
    ;              367.125 (even)
    if n_elements(flyingfocus) eq 0 $
      then flyingfocus    = max(alignment) ne 0
    if flyingfocus eq 0   $
      then fan_coroffset = (1.25 + 1.0) / det_rebin $ ;no flying focal spot     ; was 1.0    ; (1.25 + 0.5) 2017/01/12
      else fan_coroffset = (1.125 + 1.0) / det_rebin ;flying focal spot         ; was 1.0

	if flyingfocus eq 0 and factor eq 2 then $         ;
      fan_coroffset = (1.125+1.0) / det_rebin * 2
	  
    if n_elements(zalignment) eq 0 then begin
      zffs = 0
    endif else begin
      zffs = max(abs(zalignment)) ne 0
    endelse
  end
  
  
  
  else : begin
    printf, -1, 'NIdef_projbio16, ctmodel ' + ctmodel + ' not supported.'
    stop
  end
endcase


; magnification from center to detector, to find real z-positions of
; the detectors
;--------
zfactor = focus2detector / focus2centermm  ;yields 1.82456

;if flyingfocus eq 0 $
;  then nviews_per_rot = 1160 $
;  else nviews_per_rot = 2320

; We work in mm, putting the rotation axis at (0,0).
; Assumption: angle = 0 ==> source is at its highest point.
;--------------------------------------------------
;center   = [0., 0., 0.]
; define the center, this is indeed the center of the system in the reconstruction,
; not the one of the image!
center   = [0., 0., mean(tablepos)] ;- [0.5, 0.5, 0.5]

hoeken   = (findgen(nchannels+1) - nchannels/2.0 + fan_coroffset) $
           * fanangle / float(nchannels)
detcols0 = focus2detector * sin(hoeken)
detrows0 = focus2detector * cos(hoeken) - focus2centermm

detplanes0 = reform(tablepos[0,*])
detplanes0 = [2 * detplanes0[0] - detplanes0[1], detplanes0]
detplanes0 = (detplanes0 - mean(detplanes0)) * zfactor
;stop
; op volgende manier minder afrondingsfouten
;ketplanes0 = reform(tablepos[0,*])
;size       =  ketplanes0[0] -  ketplanes0[1]
;ketplanes0 += size/2 
;ketplanes0 = [ketplanes0, ketplanes0[15]-size]
;ketplanes0 = double(ketplanes0) - mean(double(ketplanes0))
;ketplanes0 *= zfactor
;ketplanes0 = float(ketplanes0)
;detplanes0 = ketplanes0

detcols1   = detcols0 * 0 ;+ sourceoffset
detrows1   = detrows0 * 0 - focus2centermm
detplanes1 = detplanes0 * 0.0


; Assume image is perfectly centered in the FOV
;--------
if n_elements(imgcol0) eq 0 then imgcol0   = - ncols / 2.0 * pixelsizemm
if n_elements(imgrow0) eq 0 then imgrow0   = - nrows / 2.0 * pixelsizemm

if n_elements(imgplane0) eq 0 $
  then imgplane0 = (max(tablepos) + min(tablepos))/2.0 - nplanes/2.0 $
       * planesepmm
if n_elements(coloffset) ne 0 then imgcol0 -= coloffset
if n_elements(rowoffset) ne 0 then imgrow0 -= rowoffset


if keyword_set(trim) then begin
  print, 'TRIM not yet supported for spiral ct mode'
  print, ' !!! Define the borders yourself !!! '
  borders = intarr(4, n_elements(tubeangle)) -1
endif else begin
  trim = [0, nchannels-1]
  borders = -1
endelse

if keyword_set(scale_fac) then begin
  ncols       *= scale_fac
  nrows       *= scale_fac
  pixelsizemm /= scale_fac

endif

if keyword_set(scale_det) then begin
  nrdet = n_elements(detcols0)-1
  detcols0_oud = detcols0
  detcols0 = interpol(detcols0, nrdet*scale_det +1, /spline)
  detcols1 = fltarr(nrdet*scale_det+1) + detcols1[0]
  
  detrows0 = interpol(detrows0, detcols0_oud, detcols0)
  detrows1 = fltarr(nrdet*scale_det+1) + detrows1[0]
  detcols0_oud = 0
endif

if zffs $
  then zalign_mm = zalignment $
  ;else zalign_mm = 0.0                    
  else zalign_mm = align_mm * 0     ; prevent errors in niproj_distd_spiralct_ocl_pic.pro

; Because the anode is (strongly) tilted with angle ANODEANGLE, 
; the focus unavoidably moves up and down when it is moved in the z
; direction to implement the z-flying focal spot. The anode angle is
; 7-9 degrees, with 0 degrees meaning it is perfectly vertical, so the
; radial motion (side effect) is in fact much larger than the z-motion
; (intended effect).
; The radial motion of the focus is zalign / tan(anodeangle)
if n_elements(anodeangle) eq 0 $
  then zalign_cotg = 0. $
  else zalign_cotg = 1.0 / tan(anodeangle)

  ; The vox_offset was defined outside
  if keyword_set(raytracing) eq 1 then begin
     vox_offset = [(center[0]-coloffset)/pixelsizemm,(center[1]-rowoffset)/pixelsizemm, (center[2]-planeoffset)/planesepmm ] $
       -[ncols-1, nrows-1, nplanes-1] / 2.
   endif else begin
     vox_offset = [(center[0]-coloffset)/pixelsizemm,(center[1]-rowoffset)/pixelsizemm, (center[2]-planeoffset)/planesepmm ] $
       -[ncols-1, nrows-1, nplanes-1] / 2.     -[0.5,0.5,0.5]        ;
   endelse
  
  
;stop
  
  ; initilize the bridge
  ; ------------------------------------------------------------------------------------
  sinorebin = 1         ; only needed for 'distd_volume.cl'
 ;-- Parameters to string
  pix_size = string(pixelsizemm) + 'f'
  pix_size = strcompress(pixelsizemm, /remove_all)

  srebin = string(1./sinorebin) + 'f'
  srebin = strcompress(srebin, /remove_all)
 

 ;-- Projector
  temp = '-D SPIRAL -D CBCT'
  if keyword_set(rigmotion)    and n_elements(rigmotion) gt 1 then temp += ' -D MC'
  if keyword_set(nonrigmotion) and n_elements(nonrigmotion) gt 1 then temp += ' -D NMC'
  if keyword_set(force_cpu)    then temp += ' -D RUN_ON_CPU'
  if keyword_set(fast_math)    then temp += ' -D FAST_MATH'
  if keyword_set(smallbin)     then temp += ' -D SMALLBIN'
  compile_options = temp
  if keyword_set(flat) then begin
    file_paths = NIpath_kernels + 'distd_sinogram.cl'                          ; deprecated
  endif else if keyword_set(opt_mem) then begin
    file_paths  = NIpath_kernels + 'distd_sinogram_spiralct_pic_mem.cl'             ; deprecated
  endif else begin
    if not keyword_set(raytracing) then begin
      file_paths  = NIpath_kernels + 'distd_sinogram_spiralct_pic.cl'
    endif else begin
	  if keyword_set(nonrigmotion) then begin
        file_paths  = NIpath_kernels + 'rayt_sinogram_spiralct_pic_nonrig.cl'   
	  endif else  file_paths  = NIpath_kernels +'rayt_sinogram_spiralct_pic.cl'
    endelse
  endelse
  function_names  = 'main_kernel'
  idl_call_names  = 'proj'

  ;-- Backprojector
  temp  =  '-D SPIRAL -D CBCT'
  temp += ' -D BACK_PROJECT' 
;  temp += ' -D SINO_PIX_X=' + pix_size
;  temp += ' -D PM_REBIN='   + srebin
  if keyword_set(rigmotion)    and n_elements(rigmotion) gt 1 then temp += ' -D MC'
  if keyword_set(nonrigmotion) and n_elements(nonrigmotion) gt 1 then temp += ' -D NMC'
  if keyword_set(force_cpu)    then temp += ' -D RUN_ON_CPU'
  if keyword_set(fast_math)    then temp += ' -D FAST_MATH'
  if keyword_set(smallbin)     then temp += ' -D SMALLBIN'
  compile_options = [compile_options,temp]
  if keyword_set(flat) then begin
    file_paths  = [file_paths, NIpath_kernels + 'distd_sinogram.cl']
  endif else if keyword_set(opt_mem) then begin
    file_paths  = [file_paths, NIpath_kernels + 'distd_sinogram_spiralct_pic_mem.cl']
  endif else begin
    if not keyword_set(raytracing) then begin
      file_paths  = [file_paths, NIpath_kernels + 'distd_sinogram_spiralct_pic.cl']
    endif else begin
      if keyword_set(nonrigmotion) then begin
        file_paths  =  [file_paths, NIpath_kernels + 'rayt_sinogram_spiralct_pic_nonrig.cl']   
	  endif else  file_paths  =  [file_paths, NIpath_kernels +'rayt_sinogram_spiralct_pic.cl']
    endelse
  endelse
  function_names  = [function_names,'main_kernel']
  idl_call_names  = [idl_call_names,'back']

;  ;-- Backprojector, parallel through the volume with the assumption that the z planes has to parallel to the detector
;  temp  =  '-D CBCT' ; add '-D BACK_PROJECT when using distd_sinogram.cl
;  temp += ' -D SINO_PIX_X=' + pix_size
;  temp += ' -D PM_REBIN='   + srebin
;  if keyword_set(force_cpu) then temp += ' -D RUN_ON_CPU'
;  if keyword_set(fast_math) then temp += ' -D FAST_MATH'
;  compile_options = [compile_options,temp]
;  file_paths      = [file_paths, NIpath_kernels + 'distd_volume.cl']
;  function_names  = [function_names,'main_kernel']
;  idl_call_names  = [idl_call_names,'back']



  ;-- Actual bridge creation
  oclbridge = obj_new('niopencl')
  
  b = oclbridge->create_command_queue()

  b = oclbridge->build_kernels(file_paths,     $
                               function_names, $
                               idl_call_names, $
                               compile_options)
							   

;if keyword_set(coords_array) eq 0 then coords_array = -1
if keyword_set(detbins) eq 0 then detbins = -1
if keyword_set(srclocs) eq 0 then srclocs = -1

if not keyword_set(raytracing) then begin
  ;nchannels1 = nchannels/2
 ; Initial coordinates for the kernel, instead we can supply the 
  ; whole set of coordinates after transform too, but this seems more efficient
  npoints = (nchannels+1)* (ndetplanes+1)+1 +1           ; center, source and detector
  initial_coords = make_array(4, npoints, /float, value=1.0)
  initial_coords[0:2,0]   = center ;[0.0, 0.0, 0.0]  
  initial_coords[3,0]   = 0.
  initial_coords[0,1]   = mean(detcols1)
  initial_coords[1,1]   = mean(detrows1)
  initial_coords[2,1]   = mean(detplanes1)
  initial_coords[0,2:npoints-1] = detcols0 # (fltarr(1,ndetplanes+1)+1)
  initial_coords[1,2:npoints-1] = detrows0 # (fltarr(1,ndetplanes+1)+1)
  initial_coords[2,2:npoints-1] = (fltarr(nchannels+1,1)+1) # reform(detplanes0,1,ndetplanes+1)
  
;stop

  projdescrip = {type          : 'distd_spiralct_ocl', $
    nrcols        : ncols, $
    nrrows        : nrows, $
    nrplanes      : nplanes, $
    ndetcols      : nchannels, $
    ndetplanes    : ndetplanes, $
    detcols0      : detcols0, $  ;to be rotated
    detcols1      : detcols1, $
    detrows0      : detrows0, $
    detrows1      : detrows1, $
    detplanes0    : detplanes0, $ ; to be recalculated from tablepos
    detplanes1    : detplanes1, $
    center        : center, $
    angles        : float(tubeangle), $
    align         : align_mm, $
    zffs          : zffs, $        ;1 = z-flying focal spot is used
    zalign        : zalign_mm, $
    zalign_cotg   : zalign_cotg, $   ;radial effect of z-FFS
    nrangles      : n_elements(tubeangle), $
    imgcol0       : imgcol0, $
    imgrow0       : imgrow0, $
    imgplane0     : imgplane0, $
    imgcolwidth   : pixelsizemm, $
    imgrowwidth   : pixelsizemm, $
    imgplanewidth : planesepmm, $
    volumefwhm    : volumefwhm, $
    fwhm          : fwhm, $
    tablepos      : tablepos, $  ;array of nrangles x nplanes
    zfactor       : zfactor, $
    rigmotion     : rigmotion, $
    raytracing    : keyword_set(raytracing), $
    unit_in_mm    : 1., $
	trim          : trim, $
    borders       : borders, $
    detbins       : detbins, $
    srclocs       : srclocs, $
    radius        : focus2detector,  $
    fanangle      : fanangle,  $
    focus2center  : focus2centermm,  $
    detpixsizemm  : detpixsizemm,  $
    fpixelsizemm  : fpixelsizemm, $
    fast_math     : fast_math,  $
    force_cpu     : force_cpu,  $
    oclbridge     : oclbridge,  $
    flat          : flat,   $
    parse_initial : parse_initial,   $
    opt_mem       : opt_mem, $
    vox_offset    : vox_offset, $
    initial_coords: initial_coords, $
    kernel_path   : kernel_path}  ;since imgcolwidth etc are in mm.}



    
endif else begin
  ; make a copy of old coordinates, as all program assume detector boundaries were used
  detcols0_dd   = detcols0   
  detrows0_dd   = detrows0
  detcols1_dd   = detcols1
  detrows1_dd   = detrows1
  detplanes0_dd = detplanes0
  detplanes1_dd = detplanes1
  
  ; We now have to convert detector boundaries to detectorcenters
  ;--------------------------------------------------------------
  if n_elements(detcols0) eq 1 $
    then detcols0 += fltarr(nchannels) $
  else  detcols0 = (detcols0[0:nchannels-1,*] + detcols0[1:nchannels,*])/2.0
  
  if n_elements(detrows0) eq 1 $
    then detrows0 += fltarr(nchannels) $
  else detrows0 = (detrows0[0:nchannels-1,*] + detrows0[1:nchannels,*])/2.0
  
  if n_elements(detcols1) eq 1 $
    then detcols1 += fltarr(nchannels) $
  else detcols1 = (detcols1[0:nchannels-1,*] + detcols1[1:nchannels,*])/2.0
  
  if n_elements(detrows1) eq 1 $
    then detrows1 += fltarr(nchannels) $
  else detrows1 = (detrows1[0:nchannels-1,*] + detrows1[1:nchannels,*])/2.0
  
  if n_elements(detplanes0) gt 1 then begin
    if (size(detplanes0))[0] eq 1 $
      then detplanes0 = (detplanes0[0:ndetplanes-1] + detplanes0[1:ndetplanes])/2.0 $
    else detplanes0 = (detplanes0[*,0:ndetplanes-1] + detplanes0[*,1:ndetplanes])/2.0
  endif
  if n_elements(detplanes1) gt 1 then begin
    if (size(detplanes1))[0] eq 1 $
      then detplanes1 = (detplanes1[0:ndetplanes-1] + detplanes1[1:ndetplanes])/2.0 $
    else detplanes1 = (detplanes1[*,0:ndetplanes-1] + detplanes1[*,1:ndetplanes])/2.0
  endif
  
  
  ; Initial coordinates for the kernel, instead we can supply the 
  ; whole set of coordinates after transform too, but this seems more efficient
  npoints = nchannels* ndetplanes+1 +1           ; center, source and detector
  initial_coords = make_array(4, npoints, /float, value=1.0)
  initial_coords[0:2,0]   = center     ;[0.0,0.0,0.0]  
  initial_coords[3,0]   = 0.
  initial_coords[0,1]   = mean(detcols1)
  initial_coords[1,1]   = mean(detrows1)
  initial_coords[2,1]   = mean(detplanes1)
  initial_coords[0,2:npoints-1] = detcols0 # (fltarr(1,ndetplanes)+1)
  initial_coords[1,2:npoints-1] = detrows0 # (fltarr(1,ndetplanes)+1)
  initial_coords[2,2:npoints-1] = (fltarr(nchannels,1)+1) # reform(detplanes0,1,ndetplanes)
  
  ; Reorder the detector elements in one view, this was only intended for opencl
  if keyword_set(reorder) then begin
  ; ----------------------------------------------
    initial_coords1 = initial_coords[*,0:1]
    div = 920 * 15 -100
    if n_elements(detcols1) mod div eq 0  then print, 'warning: divide factor is a multiple of transaxial detector elements!'
    fold = (npoints-2) / div
    
    for i = 0, div-1 do begin
      for j = 0, fold-1 do begin
        index = j * div + i
        initial_coords1 = [[initial_coords1],[initial_coords[*,index+2]]]
      ;print, initial_coords1
      ;stop
      endfor
    endfor
    res = (npoints-2) mod div
    initial_coords1 = [[initial_coords1],[initial_coords[*,npoints-res:npoints-1]]]
    initial_coords = initial_coords1
  ; -------------------------------------------------
  endif
;stop
  
  if not keyword_set(nonrigmotion) then nonrigmotion = 0
  
  projdescrip = {type          : 'rayt_spiralct_ocl', $
    nrcols        : ncols, $
    nrrows        : nrows, $
    nrplanes      : nplanes, $
    ndetcols      : nchannels, $
    ndetplanes    : ndetplanes, $
    detcols0      : detcols0_dd, $  ;to be rotated
    detcols1      : detcols1_dd, $
    detrows0      : detrows0_dd, $
    detrows1      : detrows1_dd, $
    detplanes0    : detplanes0_dd, $ ; to be recalculated from tablepos
    detplanes1    : detplanes1_dd, $
    center        : center, $
    angles        : float(tubeangle), $
    align         : align_mm, $
    zffs          : zffs, $        ;1 = z-flying focal spot is used
    zalign        : zalign_mm, $
    zalign_cotg   : zalign_cotg, $   ;radial effect of z-FFS
    nrangles      : n_elements(tubeangle), $
    imgcol0       : imgcol0, $
    imgrow0       : imgrow0, $
    imgplane0     : imgplane0, $
    imgcolwidth   : pixelsizemm, $
    imgrowwidth   : pixelsizemm, $
    imgplanewidth : planesepmm, $
    volumefwhm    : volumefwhm, $
    fwhm          : fwhm, $               ;0.0
    tablepos      : tablepos, $  ;array of nrangles x nplanes
    zfactor       : zfactor, $
    rigmotion     : rigmotion, $
	nonrigmotion  : nonrigmotion, $
    raytracing    : keyword_set(raytracing), $
    unit_in_mm    : 1., $
	trim          : trim, $
    borders       : borders, $
    detbins       : detbins, $
    srclocs       : srclocs, $
    radius        : focus2detector,  $
    fanangle      : fanangle,  $
    focus2center  : focus2centermm,  $
    detpixsizemm  : detpixsizemm,  $
	fpixelsizemm  : fpixelsizemm, $
    fast_math     : fast_math,  $
    force_cpu     : force_cpu,  $
    oclbridge     : oclbridge,  $
    flat          : flat,   $
    parse_initial : parse_initial,   $
    opt_mem       : opt_mem, $
    vox_offset    : vox_offset, $
    initial_coords: initial_coords, $
    kernel_path   : kernel_path}  ;since imgcolwidth etc are in mm.}
    
    
endelse

return, projdescrip
end
