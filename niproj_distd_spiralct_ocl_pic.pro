;+
; NAME:
;    NIproj_distd_spiralct
;
; PURPOSE:
;    Distance driven projection using a structure created by
;    NIdef_projdistd. Useful for cylindrical systems with helical
;    acquisition orbit. The projector currently supported is
;    "distd_spiralct".  Intended to be called by NIproj, there should
;    be no need to call this routine directly.
;
;
; CATEGORY:
;    reconstruction
;
; CALLING SEQUENCE:
;    NIproj_distd_spiralct, image, sinogram, ...
;
; INPUTS:
;    IMAGE
;      when BACKPROJECT is not set, IMAGE is projected into SINOGRAM.
;
;    SINOGRAM
;      when BACKPROJECT is set, SINONGRAM is backprojected into IMAGE
;
;
; OPTIONAL INPUTS:
;    none
;
;
; KEYWORD PARAMETERS:
;    BACKPROJECT:
;      when set, a backprojection is computed. Otherwise a projection
;      is computed.
;
;    SUBSET:
;      an array with the indices of the projections to be used for the
;      (back)projection. Default is all angles.
;
;    SUBONLY
;      when set, input and output for the (back)projection have the
;      size of sinogram[*,subset,*]. Make sure all other sinogram-like
;      variable (e.g. attenuation) are also given for subsets angles only.
;
;    NEW:
;      when set, the output array (IMAGE or SINOGRAM) is set to zero
;      before the (back)projection.
;
;    PROJDESCRIP:
;      a structure produced with NIdef_projdistd, which in turn may
;      have been called by NIdef_proj. PROJDESCRIP.type should be
;      'distd'.
;
;    ATTENUATION
;      an array with the same size as the sinogram, representing the
;      effect of PET attenuation.
;
;    SCALEFACTOR
;      the result of projection or backprojection is multiplied with
;      this scalefactor (assumed to be a scalar).
;
; OUTPUTS:
;    IMAGE:     see INPUTS
;    SINOGRAM:  see INPUTS
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
;    Currently no SPECT attenuation is supported
;
; PROCEDURE:
;    Calls NIdistd_proj3d_1angle to do the work.
;    Procedure is the same as in NIproj_distd, except that for each
;    angle, the plane position is computed from additional information
;    in PROJDESCRIP.
;
; EXAMPLE:
;
;
; SEE ALSO:
;    NIproj, NIdistd_proj3d_1angle, NIproj_distd, NIdef_proj
;
; MODIFICATION HISTORY:
; 	Written by:	Johan Nuyts, feb 2010
;          JN, aug 2012: checks projdescrip.raytracing to see if ray
;                        tracing should be used instead of distance driven.
;-    support patch reconstruction
;-

compile_opt strictarrsubs

pro NIproj_distd_spiralct_ocl_pic, image, sinogram, backproject = backproject, $
    subset = subset, new = new, projdescrip = projdescrip, $
    attenuation = attenuation, scalefactor = scalefactor, $
    calctime = calctime, subonly = subonly, holes=holes, where_holes=where_holes
    
  calctime = 0.0
  if projdescrip.type ne 'distd_spiralct_ocl' then begin
    printf,-1, 'NIproj_distd_spiralct_ocl: wrong type of projector <' $
      + projdescrip.type + '>'
    return
  endif
  
  if projdescrip.borders[0] eq -1 then begin
    gmin = fltarr(projdescrip.nrangles)
    gmax = gmin + projdescrip.ndetcols-1
  endif else begin
    gmin = reform(projdescrip.borders[0,*])
    gmax = reform(projdescrip.borders[1,*])
  endelse
  
  if n_elements(scalefactor) eq 0 $
    then scalefactor = 1.0
    
  ; Use all angles if no subset is specified.
  ;------
  if n_elements(subset) eq 0 $
    then subset = lindgen(projdescrip.nrangles)
    
  ; Allocate images if they are not yet available
  ;------
  if keyword_set(backproject) then begin
    if projdescrip.nrplanes eq 0 then begin
      nrplanes = 1
    endif else begin
      nrplanes = projdescrip.nrplanes
    endelse
    if n_elements(image) le 1 $
      then image = fltarr(projdescrip.nrcols, projdescrip.nrrows, $
      nrplanes)
  endif else begin
    if projdescrip.ndetplanes eq 0 then begin
      ndetplanes = 1
    endif else begin
      ndetplanes = projdescrip.ndetplanes
    endelse
    if n_elements(sinogram) le 1 then begin
      if keyword_set(subonly) $
        then sinogram = fltarr(projdescrip.ndetcols, n_elements(subset), $
        ndetplanes) $
      else sinogram = fltarr(projdescrip.ndetcols, projdescrip.nrangles, $
      ndetplanes)
  endif
endelse

; Erase if requested.
;-------
if keyword_set(new) then $
  if keyword_set(backproject) then image    = image    * 0.0 $
                       else sinogram = sinogram * 0.0

; Find fwhm_t and fwhm_a (transaxial and axial)
;-------
fwhm_t = float(projdescrip.fwhm[0])
if n_elements(projdescrip.fwhm) lt 2 $
  then fwhm_a = fwhm_t $
else fwhm_a = float(projdescrip.fwhm[1])

; Find fwhm_xy and fwhm_z (volumetric resolution modelling)
;-------
fwhm_xy = projdescrip.volumefwhm[0]
if n_elements(projdescrip.volumefwhm) eq 2 $
  then fwhm_z = projdescrip.volumefwhm[1] $
else fwhm_z = fwhm_xy





;== Set some variables
true   = 1
false  = 0
bridge = projdescrip.oclbridge
voxdim = projdescrip.imgcolwidth               ; imgplanewidth
;coords_array = projdescrip.coords_array
;ndetcols = (size(projdescrip.detcols0))[1]
;ndetrows = (size(projdescrip.detrows0))[1]

;if NOT keyword_set(subset) then subset = lindgen(projdescrip.nrangles)
nrangles = n_elements(subset)



;== Some fixed input parameters
size_img   = [(size(image))[1:3],1UL]                         ;
;size_sino  = [projdescrip.ndetcols,projdescrip.ndetplanes,nrangles,1UL]
size_sino  = [projdescrip.trim[1]-projdescrip.trim[0]+1,projdescrip.ndetplanes,nrangles,1UL]
vox_size   = [voxdim, voxdim, projdescrip.imgplanewidth, 0.]
img_offset = [projdescrip.vox_offset * vox_size, 1UL]      ;- size_img * vox_size / 2.
;img_offset = [0.,0.,0.,0.]
zalign_cotg = [projdescrip.zalign_cotg, 0.,0.,0.]
;detbins0    = projdescrip.initial_coords

npoints     = (size(projdescrip.initial_coords))[2]
detbins0    = reform(projdescrip.initial_coords[*,2:npoints-1], 4,projdescrip.ndetcols +1,projdescrip.ndetplanes +1)
detbins0    = detbins0[*,projdescrip.trim[0]:(projdescrip.trim[1]+1),*]
npoints     = (projdescrip.trim[1]-projdescrip.trim[0]+1 +1) * (projdescrip.ndetplanes +1)
detbins0    = reform(detbins0, 4,npoints)
detbins0    = [[projdescrip.initial_coords[*,0:1]], [detbins0]]


;stop

;subset1 = subset[0:nrangles/2]
;subset2 = subset[nrangles/2:nrangles-1]
;subsetnew = subset * 0
;for isub = 0, nrangles/2-1  do $
;  subsetnew[isub*2:isub*2+1] = [subset1[isub], subset2[isub]]
;  subset = subsetnew


; get the coordinates for current subset
;detbins  = fltarr(4,8,nrangles)
srclocs0  = fltarr(4,nrangles)
rigmotion = fltarr(4,4,nrangles)
;angles   = fltarr(nrangles)
;tablepos = fltarr(nrangles, projdescrip.ndetplanes)


for ii = 0L, nrangles-1 do begin
  ;  detbins[*,*,ii] = projdescrip.detbins[*,*, subset[ii]]
  ;  srclocs[*,ii] = projdescrip.srclocs[*, subset[ii]]
  ;  angles[ii] = projdescrip.angles[subset[ii]]
  ;  tablepos[ii,*] = projdescrip.tablepos[subset[ii], *]
  ;  tableposmean[ii] = mean(projdescrip.tablepos[subset[ii], *])
  srclocs0[0,ii] = projdescrip.angles[subset[ii]]
  srclocs0[1,ii] = mean(projdescrip.tablepos[subset[ii], *])
  srclocs0[2,ii] = projdescrip.align[subset[ii]]
  srclocs0[3,ii] = projdescrip.zalign[subset[ii]]
  
  if n_elements(projdescrip.rigmotion) gt 1  then begin
    dof = projdescrip.rigmotion[*,subset[ii]]
    rigmotion[*,*,ii] = NImotion2matrix(motion=dof, /homo)               ; not the one in IDL!    
  endif else begin
;    rigmotion = 0.
  endelse
  
endfor



;profiler
;profiler, /system


;if keyword_set(subonly)              $
;  then sinoproj = sinogram           $
;else sinoproj = sinogram[*,subset,*]

if keyword_set(subonly)              $
  then sinoproj = sinogram[projdescrip.trim[0]:projdescrip.trim[1],*,*]           $
else sinoproj = sinogram[projdescrip.trim[0]:projdescrip.trim[1],subset,*]

niswyz, sinoproj

if keyword_set(backproject) then begin
  ;if (n_elements(image) LE 1)  OR (keyword_set(new)) then    $
  ;  image = fltarr(projdescrip.nrcols,                      $
  ;  projdescrip.nrrows,                      $
  ;  projdescrip.nrplanes)
  
    ;tmpimage = image * 0.0
    ; resolution in sinogram
    if fwhm_t gt 0 $
      then sinogram = NIconvolgauss(sinogram, fwhm = fwhm_t, dim=0)
    if fwhm_a gt 0 $
      then sinogram = NIconvolgauss(sinogram, fwhm = fwhm_a, dim=1)
    
endif else begin
  ;if (n_elements(sinogram) LE 1)  OR (keyword_set(new)) then $
  ;  sinogram = fltarr(projdescrip.ndetcols,                 $
  ;  nrangles,                 $
  ;  projdescrip.ndetrows)
    
    ; resolution modelling
    if fwhm_xy gt 0 or fwhm_z gt 0 then begin
      image = NIconvolgauss(image, fwhm = fwhm_xy, dim = [0,1], nrsig = 3)
      image = NIconvolgauss(image, fwhm = fwhm_z, dim = [2], nrsig = 3)
    endif else begin
      ;tmpimage = image
    endelse
endelse




; ------------------------------------------------------------------------------------------------
; ------------------------------------------ test the kernel code --------------------------------
; ------------------------------------------------------------------------------------------------
;fanangle       = projdescrip.fanangle
;radius         = projdescrip.radius
;focus2center   = projdescrip.focus2center
;detbins0        = projdescrip.initial_coords



;stop
;start_time = systime(1)

;== Allocate buffers & write data
bptr_image   =  0L
bptr_sino    =  1L
;bptr_detbins =  2L
bptr_srclocs0 =  2L
;bptr_angles  =  2L
;bptr_detplanes= 3L
;bptr_tablepos =  3L
bptr_detbins0 =  3L
bptr_mc       = 4L
;bptr_debug   =  5L


b = bridge->create_buffer(bptr_image,   image,    0, 0)
b = bridge->create_buffer(bptr_sino,    sinoproj, 0, 0)
;b = bridge->create_buffer(bptr_detbins, detbins,  2, 0)
b = bridge->create_buffer(bptr_srclocs0, srclocs0,  2, 0)
;b = bridge->create_buffer(bptr_angles,  angles,   2, 0)
;b = bridge->create_buffer(bptr_detplanes, detplanes,  2, 0)
;b = bridge->create_buffer(bptr_tablepos, tableposmean,  2, 0)
b = bridge->create_buffer(bptr_detbins0, detbins0,  2, 0)
b = bridge->create_buffer(bptr_mc, rigmotion, 2,0)
;output = fltarr(4, nrangles)   ;sinoproj                        ; shouldn't turn on if too many views at one time
;output = fltarr(6)
;b = bridge->create_buffer(bptr_debug, output,  0, 0)       ;write_only;


if keyword_set(backproject) then begin
  kernel = 'back'
endif else begin
  if keyword_set(expmin) then begin
    kernel = 'projexpmin'
  endif else begin
    kernel = 'proj'
  endelse
endelse

;== Set kernel arguments
b = bridge->set_kernel_arg(kernel, 0, bptr_image,   true)
b = bridge->set_kernel_arg(kernel, 1, bptr_sino,    true)
;b = bridge->set_kernel_arg(kernel, 2, bptr_detbins, true)
b = bridge->set_kernel_arg(kernel, 2, bptr_srclocs0, true)
;b = bridge->set_kernel_arg(kernel, 2, bptr_angles,  true)
;b = bridge->set_kernel_arg(kernel, 3, bptr_detplanes,true)
;b = bridge->set_kernel_arg(kernel, 3, bptr_tablepos, true)
b = bridge->set_kernel_arg(kernel, 3, bptr_detbins0, true)

b = bridge->set_kernel_arg(kernel, 4, size_img,   false)
b = bridge->set_kernel_arg(kernel, 5, size_sino,  false)
b = bridge->set_kernel_arg(kernel, 6, img_offset, false)
b = bridge->set_kernel_arg(kernel, 7, vox_size,   false)
b = bridge->set_kernel_arg(kernel, 8, zalign_cotg,false)
;b = bridge->set_kernel_arg(kernel, 9, fanangle,  false)
;b = bridge->set_kernel_arg(kernel, 10, radius,  false)
;b = bridge->set_kernel_arg(kernel, 11, focus2center,  false)
b = bridge->set_kernel_arg(kernel, 9, bptr_mc, true)
;var_deb = 0.
;b = bridge->set_kernel_arg(kernel, 10, bptr_debug, true)

;== Actual work
global = ulong(size_sino[0:2])
local  = ulong([0,0,0])

; depend on parallel through volume or sinogram
;  if keyword_set(backproject)         $
;    then global = ulong(size_img[0:2])$
;    else global = ulong(size_sino[0:2])

;start_time = systime(1)
b = bridge->execute_kernel(kernel, global, local, false)
;print, keyword_set(backproject), 'opencl time:', (systime(1)-start_time)/60.

;== Read out data
if keyword_set(backproject) then begin
  b = bridge->read_buffer(bptr_image, image)
  image /= nrangles
  
   ; resoultion modelling
   if fwhm_xy gt 0 or fwhm_z gt 0 then begin
      image = NIconvolgauss(image, fwhm = fwhm_xy, dim = [0,1], nrsig = 3)
      image = NIconvolgauss(image, fwhm = fwhm_z, dim = [2], nrsig = 3)
   endif
   
  ; erase part when keyword_set(holes)
  if keyword_set(holes) then begin
    if size(where_holes,/type) ne 10 then begin
      nrholes = n_elements(where_holes[0,*])
      for nrh = 0, nrholes-1 do begin
        image[where_holes[0, nrh]:where_holes[1, nrh], $
              where_holes[2, nrh]:where_holes[3, nrh], $
              where_holes[4, nrh]:where_holes[5, nrh]] = 0.
      endfor
    endif else begin
      for pc = 0, n_elements(where_holes)-1  do $
        image(*where_holes[pc]) = 0
    endelse
  endif
  ;if keyword_set(holes) then stop
   
   
   ;image += tmpimage
endif else begin
  b = bridge->read_buffer(bptr_sino, sinoproj)

  niswyz, sinoproj
  ; resolution in sinogram
  if fwhm_t gt 0 $
      then sinoproj = NIconvolgauss(sinoproj, fwhm = fwhm_t, dim=0)
  if fwhm_a gt 0 $
      then sinoproj = NIconvolgauss(sinoproj, fwhm = fwhm_a, dim=1)
  
;  if keyword_set(subonly)                $
;    then sinogram             = sinoproj $
;  else sinogram[*,subset,*] = sinoproj
  

  if keyword_set(subonly)                $
    then sinogram[projdescrip.trim[0]:projdescrip.trim[1], *,*]  += sinoproj $
  else sinogram[projdescrip.trim[0]:projdescrip.trim[1],subset,*] += sinoproj
endelse
;stop

;b = bridge->read_buffer(bptr_angles, angles)
;b = bridge->read_buffer(bptr_detplanes, detplanes)
;b = bridge->read_buffer(bptr_detbins0, detbins0)
;b = bridge->read_buffer(bptr_tablepos, tableposmean)
;b = bridge->read_buffer(bptr_debug, output)


;== Clean up buffers
b = bridge->release_buffer(bptr_image)
b = bridge->release_buffer(bptr_sino)
b = bridge->release_buffer(bptr_detbins0)
b = bridge->release_buffer(bptr_srclocs0)
;b = bridge->release_buffer(bptr_angles)
;b = bridge->release_buffer(bptr_detplanes)
;b = bridge->release_buffer(bptr_tablepos)
b = bridge->release_buffer(bptr_mc)
;b = bridge->release_buffer(bptr_debug)

;print, keyword_set(backproject), 'opencl time:', (systime(1)-start_time)/60.
;stop

;profiler, /report;, filename = 'profiler.txt'
;print, ''



end