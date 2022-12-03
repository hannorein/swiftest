!! Copyright 2022 - David Minton, Carlisle Wishard, Jennifer Pouplin, Jake Elliott, & Dana Singh
!! This file is part of Swiftest.
!! Swiftest is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License 
!! as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
!! Swiftest is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
!! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
!! You should have received a copy of the GNU General Public License along with Swiftest. 
!! If not, see: https://www.gnu.org/licenses. 

submodule (swiftest_classes) s_netcdf
   use swiftest
   use netcdf
contains

   module subroutine check(status, call_identifier)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Checks the status of all NetCDF operations to catch errors
      implicit none
      ! Arguments
      integer, intent (in) :: status !! The status code returned by a NetCDF function
      character(len=*), intent(in), optional :: call_identifier !! String that indicates which calling function caused the error for diagnostic purposes

      if(status /= nf90_noerr) then
         if (present(call_identifier)) write(*,*) "NetCDF error in ",trim(call_identifier)
         write(*,*) trim(nf90_strerror(status))
         call util_exit(FAILURE)
      end if

      return
   end subroutine check


   module subroutine netcdf_close(self)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Closes a NetCDF file
      implicit none
      ! Arguments
      class(netcdf_parameters),   intent(inout) :: self   !! Parameters used to identify a particular NetCDF dataset

      call check( nf90_close(self%id), "netcdf_close" )

      return
   end subroutine netcdf_close


   module subroutine netcdf_flush(self, param)
      !! author: David A. Minton
      !!
      !! Flushes the current buffer to disk by closing and re-opening the file.
      !!    
      implicit none
      ! Arguments
      class(netcdf_parameters),   intent(inout) :: self !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters), intent(inout) :: param !! Current run configuration parameters 

      call self%close()
      call self%open(param)

      return
   end subroutine netcdf_flush


   module function netcdf_get_old_t_final_system(self, param) result(old_t_final)
      !! author: David A. Minton
      !!
      !! Validates the dump file to check whether the dump file initial conditions duplicate the last frame of the netcdf output.
      !!
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(inout) :: self
      class(swiftest_parameters),   intent(inout) :: param
      ! Result
      real(DP)                                    :: old_t_final
      ! Internals
      integer(I4B)                              :: itmax, idmax
      real(DP), dimension(:), allocatable       :: vals
      real(DP), dimension(1)                    :: val
      real(DP), dimension(NDIM)                 :: rot0, Ip0, Lnow
      real(DP) :: KE_orb_orig, KE_spin_orig, PE_orig

      call param%nciu%open(param)
      call check( nf90_inquire_dimension(param%nciu%id, param%nciu%time_dimid, len=itmax), "netcdf_get_old_t_final_system time_dimid" )
      call check( nf90_inquire_dimension(param%nciu%id, param%nciu%id_dimid, len=idmax), "netcdf_get_old_t_final_system id_dimid" )
      allocate(vals(idmax))
      call check( nf90_get_var(param%nciu%id, param%nciu%time_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system time_varid" )

      !old_t_final = val(1)
      old_t_final = param%t0 ! For NetCDF it is safe to overwrite the final t value on a restart

      if (param%lenergy) then
         call check( nf90_get_var(param%nciu%id, param%nciu%KE_orb_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system KE_orb_varid" )
         KE_orb_orig = val(1)

         call check( nf90_get_var(param%nciu%id, param%nciu%KE_spin_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system KE_spin_varid" )
         KE_spin_orig = val(1)

         call check( nf90_get_var(param%nciu%id, param%nciu%PE_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system PE_varid" )
         PE_orig = val(1)

         call check( nf90_get_var(param%nciu%id, param%nciu%Ecollisions_varid, self%Ecollisions, start=[1]), "netcdf_get_old_t_final_system Ecollisions_varid" )
         call check( nf90_get_var(param%nciu%id, param%nciu%Euntracked_varid,  self%Euntracked,  start=[1]), "netcdf_get_old_t_final_system Euntracked_varid" )

         self%Eorbit_orig = KE_orb_orig + KE_spin_orig + PE_orig + self%Ecollisions + self%Euntracked

         call check( nf90_get_var(param%nciu%id, param%nciu%L_orbx_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_orbx_varid" )
         self%Lorbit_orig(1) = val(1)
         call check( nf90_get_var(param%nciu%id, param%nciu%L_orby_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_orby_varid" )
         self%Lorbit_orig(2) = val(1)
         call check( nf90_get_var(param%nciu%id, param%nciu%L_orbz_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_orbz_varid" )
         self%Lorbit_orig(3) = val(1)

         call check( nf90_get_var(param%nciu%id, param%nciu%L_spinx_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_spinx_varid" )
         self%Lspin_orig(1) = val(1)
         call check( nf90_get_var(param%nciu%id, param%nciu%L_spiny_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_spiny_varid" )
         self%Lspin_orig(2) = val(1)
         call check( nf90_get_var(param%nciu%id, param%nciu%L_spinz_varid, val, start=[1], count=[1]), "netcdf_get_old_t_final_system L_spinz_varid" )
         self%Lspin_orig(3) = val(1)

         call check( nf90_get_var(param%nciu%id, param%nciu%L_escapex_varid, self%Lescape(1),  start=[1]), "netcdf_get_old_t_final_system L_escapex_varid" )
         call check( nf90_get_var(param%nciu%id, param%nciu%L_escapey_varid, self%Lescape(2),  start=[1]), "netcdf_get_old_t_final_system L_escapey_varid" )
         call check( nf90_get_var(param%nciu%id, param%nciu%L_escapez_varid, self%Lescape(3),  start=[1]), "netcdf_get_old_t_final_system L_escapez_varid" )

         self%Ltot_orig(:) = self%Lorbit_orig(:) + self%Lspin_orig(:) + self%Lescape(:)

         call check( nf90_get_var(param%nciu%id, param%nciu%Gmass_varid, vals, start=[1,1], count=[idmax,1]), "netcdf_get_old_t_final_system Gmass_varid" )
         call check( nf90_get_var(param%nciu%id, param%nciu%GMescape_varid,    self%GMescape,    start=[1]), "netcdf_get_old_t_final_system GMescape_varid" )
         self%GMtot_orig = vals(1) + sum(vals(2:idmax), vals(2:idmax) == vals(2:idmax)) + self%GMescape

         select type(cb => self%cb)
         class is (symba_cb)
            cb%GM0 = vals(1)
            cb%dGM = cb%Gmass - cb%GM0

            call check( nf90_get_var(param%nciu%id, param%nciu%radius_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system radius_varid" )
            cb%R0 = val(1) 

            if (param%lrotation) then

               call check( nf90_get_var(param%nciu%id, param%nciu%rotx_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system rotx_varid" )
               rot0(1) = val(1)
               call check( nf90_get_var(param%nciu%id, param%nciu%roty_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system roty_varid" )
               rot0(2) = val(1)
               call check( nf90_get_var(param%nciu%id, param%nciu%rotz_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system rotz_varid" )
               rot0(3) = val(1)

               call check( nf90_get_var(param%nciu%id, param%nciu%Ip1_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system Ip1_varid" )
               Ip0(1) = val(1)
               call check( nf90_get_var(param%nciu%id, param%nciu%Ip2_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system Ip2_varid" )
               Ip0(2) = val(1)
               call check( nf90_get_var(param%nciu%id, param%nciu%Ip3_varid, val, start=[1,1], count=[1,1]), "netcdf_get_old_t_final_system Ip3_varid" )
               Ip0(3) = val(1)

               cb%L0(:) = Ip0(3) * cb%GM0 * cb%R0**2 * rot0(:)

               Lnow(:) = cb%Ip(3) * cb%Gmass * cb%radius**2 * cb%rot(:)
               cb%dL(:) = Lnow(:) - cb%L0(:)
            end if
         end select

      end if

      deallocate(vals)
      
      return
   end function netcdf_get_old_t_final_system


   module subroutine netcdf_initialize_output(self, param)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Initialize a NetCDF file system and defines all variables.
      use, intrinsic :: ieee_arithmetic
      implicit none
      ! Arguments
      class(netcdf_parameters),   intent(inout) :: self    !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters), intent(in)    :: param   !! Current run configuration parameters 
      ! Internals
      integer(I4B) :: nvar, varid, vartype
      real(DP) :: dfill
      real(SP) :: sfill
      logical :: fileExists
      character(len=STRMAX) :: errmsg
      integer(I4B) :: ndims

      associate(nciu => self)

         dfill = ieee_value(dfill, IEEE_QUIET_NAN)
         sfill = ieee_value(sfill, IEEE_QUIET_NAN)

         select case (param%out_type)
         case("NETCDF_FLOAT")
            nciu%out_type = NF90_FLOAT
         case("NETCDF_DOUBLE")
            nciu%out_type = NF90_DOUBLE
         end select

         ! Check if the file exists, and if it does, delete it
         inquire(file=param%outfile, exist=fileExists)
         if (fileExists) then
            open(unit=LUN, file=param%outfile, status="old", err=667, iomsg=errmsg)
            close(unit=LUN, status="delete")
         end if

         ! Create the file
         call check( nf90_create(param%outfile, NF90_NETCDF4, nciu%id), "netcdf_initialize_output nf90_create" )

         ! Dimensions
         call check( nf90_def_dim(nciu%id, nciu%time_dimname, NF90_UNLIMITED, nciu%time_dimid), "netcdf_initialize_output nf90_def_dim time_dimid" ) ! Simulation time dimension
         call check( nf90_def_dim(nciu%id, nciu%id_dimname, NF90_UNLIMITED, nciu%id_dimid), "netcdf_initialize_output nf90_def_dim id_dimid" )       ! dimension to store particle id numbers
         call check( nf90_def_dim(nciu%id, nciu%space_dimname, 3, nciu%space_dimid), "netcdf_initialize_output nf90_def_dim space_dimid" )           ! 3D space dimension
         call check( nf90_def_dim(nciu%id, nciu%str_dimname, NAMELEN, nciu%str_dimid), "netcdf_initialize_output nf90_def_dim str_dimid"  )          ! Dimension for string variables (aka character arrays)

         ! Dimension coordinates
         call check( nf90_def_var(nciu%id, nciu%time_dimname, nciu%out_type, nciu%time_dimid, nciu%time_varid), "netcdf_initialize_output nf90_def_var time_varid"  )
         call check( nf90_def_var(nciu%id, nciu%id_dimname, NF90_INT, nciu%id_dimid, nciu%id_varid), "netcdf_initialize_output nf90_def_var id_varid"  )
         call check( nf90_def_var(nciu%id, nciu%space_dimname, NF90_CHAR, nciu%space_dimid, nciu%space_varid), "netcdf_initialize_output nf90_def_var space_varid"  )

         ! Variables
         call check( nf90_def_var(nciu%id, nciu%npl_varname, NF90_INT, nciu%time_dimid, nciu%npl_varid), "netcdf_initialize_output nf90_def_var npl_varid"  )
         call check( nf90_def_var(nciu%id, nciu%ntp_varname, NF90_INT, nciu%time_dimid, nciu%ntp_varid), "netcdf_initialize_output nf90_def_var ntp_varid"  )
         if (param%integrator == SYMBA) call check( nf90_def_var(nciu%id, nciu%nplm_varname, NF90_INT, nciu%time_dimid, nciu%nplm_varid), "netcdf_initialize_output nf90_def_var nplm_varid"  )
         call check( nf90_def_var(nciu%id, nciu%name_varname, NF90_CHAR, [nciu%str_dimid, nciu%id_dimid], nciu%name_varid), "netcdf_initialize_output nf90_def_var name_varid"  )
         call check( nf90_def_var(nciu%id, nciu%ptype_varname, NF90_CHAR, [nciu%str_dimid, nciu%id_dimid], nciu%ptype_varid), "netcdf_initialize_output nf90_def_var ptype_varid"  )
         call check( nf90_def_var(nciu%id, nciu%status_varname, NF90_CHAR, [nciu%str_dimid, nciu%id_dimid], nciu%status_varid), "netcdf_initialize_output nf90_def_var status_varid"  )

         if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
            call check( nf90_def_var(nciu%id, nciu%xhx_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%xhx_varid), "netcdf_initialize_output nf90_def_var xhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%xhy_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%xhy_varid), "netcdf_initialize_output nf90_def_var xhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%xhz_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%xhz_varid), "netcdf_initialize_output nf90_def_var xhz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%vhx_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%vhx_varid), "netcdf_initialize_output nf90_def_var vhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%vhy_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%vhy_varid), "netcdf_initialize_output nf90_def_var vhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%vhz_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%vhz_varid), "netcdf_initialize_output nf90_def_var vhz_varid"  )

            !! When GR is enabled, we need to save the pseudovelocity vectors in addition to the true heliocentric velocity vectors, otherwise
            !! we cannnot expect bit-identical runs from restarted runs with GR enabled due to floating point errors during the conversion.
            if (param%lgr) then
               call check( nf90_def_var(nciu%id, nciu%gr_pseudo_vhx_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%gr_pseudo_vhx_varid), "netcdf_initialize_output nf90_def_var gr_psuedo_vhx_varid"  )
               call check( nf90_def_var(nciu%id, nciu%gr_pseudo_vhy_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%gr_pseudo_vhy_varid), "netcdf_initialize_output nf90_def_var gr_psuedo_vhy_varid"  )
               call check( nf90_def_var(nciu%id, nciu%gr_pseudo_vhz_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%gr_pseudo_vhz_varid), "netcdf_initialize_output nf90_def_var gr_psuedo_vhz_varid"  )
               nciu%lpseudo_vel_exists = .true.
            end if

         end if
      
         if ((param%out_form == "EL") .or. (param%out_form == "XVEL")) then
            call check( nf90_def_var(nciu%id, nciu%a_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%a_varid), "netcdf_initialize_output nf90_def_var a_varid"  )
            call check( nf90_def_var(nciu%id, nciu%e_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%e_varid), "netcdf_initialize_output nf90_def_var e_varid"  )
            call check( nf90_def_var(nciu%id, nciu%inc_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%inc_varid), "netcdf_initialize_output nf90_def_var inc_varid"  )
            call check( nf90_def_var(nciu%id, nciu%capom_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%capom_varid), "netcdf_initialize_output nf90_def_var capom_varid"  )
            call check( nf90_def_var(nciu%id, nciu%omega_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%omega_varid), "netcdf_initialize_output nf90_def_var omega_varid"  )
            call check( nf90_def_var(nciu%id, nciu%capm_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%capm_varid), "netcdf_initialize_output nf90_def_var capm_varid"  )
         end if

         call check( nf90_def_var(nciu%id, nciu%gmass_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%Gmass_varid), "netcdf_initialize_output nf90_def_var Gmass_varid"  )

         if (param%lrhill_present) then
            call check( nf90_def_var(nciu%id, nciu%rhill_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%rhill_varid), "netcdf_initialize_output nf90_def_var rhill_varid"  )
         end if

         if (param%lclose) then
            call check( nf90_def_var(nciu%id, nciu%radius_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%radius_varid), "netcdf_initialize_output nf90_def_var radius_varid"  )

            call check( nf90_def_var(nciu%id, nciu%origin_time_varname, nciu%out_type, nciu%id_dimid, nciu%origin_time_varid), "netcdf_initialize_output nf90_def_var origin_time_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_type_varname, NF90_CHAR, [nciu%str_dimid, nciu%id_dimid], &
                                    nciu%origin_type_varid), "netcdf_initialize_output nf90_create"  )
            call check( nf90_def_var(nciu%id, nciu%origin_xhx_varname, nciu%out_type, nciu%id_dimid, nciu%origin_xhx_varid), "netcdf_initialize_output nf90_def_var origin_xhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_xhy_varname, nciu%out_type, nciu%id_dimid, nciu%origin_xhy_varid), "netcdf_initialize_output nf90_def_var origin_xhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_xhz_varname, nciu%out_type, nciu%id_dimid, nciu%origin_xhz_varid), "netcdf_initialize_output nf90_def_var origin_xhz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_vhx_varname, nciu%out_type, nciu%id_dimid, nciu%origin_vhx_varid), "netcdf_initialize_output nf90_def_var origin_vhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_vhy_varname, nciu%out_type, nciu%id_dimid, nciu%origin_vhy_varid), "netcdf_initialize_output nf90_def_var origin_vhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%origin_vhz_varname, nciu%out_type, nciu%id_dimid,  nciu%origin_vhz_varid), "netcdf_initialize_output nf90_def_var origin_vhz_varid"  )

            call check( nf90_def_var(nciu%id, nciu%collision_id_varname, NF90_INT, nciu%id_dimid, nciu%collision_id_varid), "netcdf_initialize_output nf90_def_var collision_id_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_time_varname, nciu%out_type, nciu%id_dimid, nciu%discard_time_varid), "netcdf_initialize_output nf90_def_var discard_time_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_xhx_varname, nciu%out_type, nciu%id_dimid, nciu%discard_xhx_varid), "netcdf_initialize_output nf90_def_var discard_xhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_xhy_varname, nciu%out_type, nciu%id_dimid, nciu%discard_xhy_varid), "netcdf_initialize_output nf90_def_var discard_xhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_xhz_varname, nciu%out_type, nciu%id_dimid, nciu%discard_xhz_varid), "netcdf_initialize_output nf90_def_var discard_xhz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_vhx_varname, nciu%out_type, nciu%id_dimid, nciu%discard_vhx_varid), "netcdf_initialize_output nf90_def_var discard_vhx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_vhy_varname, nciu%out_type, nciu%id_dimid, nciu%discard_vhy_varid), "netcdf_initialize_output nf90_def_var discard_vhy_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_vhz_varname, nciu%out_type, nciu%id_dimid,  nciu%discard_vhz_varid), "netcdf_initialize_output nf90_def_var discard_vhz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%discard_body_id_varname, NF90_INT, nciu%id_dimid, nciu%discard_body_id_varid), "netcdf_initialize_output nf90_def_var discard_body_id_varid"  )
         end if

         if (param%lrotation) then
            call check( nf90_def_var(nciu%id, nciu%ip1_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%Ip1_varid), "netcdf_initialize_output nf90_def_var Ip1_varid"  )
            call check( nf90_def_var(nciu%id, nciu%ip2_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%Ip2_varid), "netcdf_initialize_output nf90_def_var Ip2_varid"  )
            call check( nf90_def_var(nciu%id, nciu%ip3_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%Ip3_varid), "netcdf_initialize_output nf90_def_var Ip3_varid"  )
            call check( nf90_def_var(nciu%id, nciu%rotx_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%rotx_varid), "netcdf_initialize_output nf90_def_var rotx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%roty_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%roty_varid), "netcdf_initialize_output nf90_def_var roty_varid"  )
            call check( nf90_def_var(nciu%id, nciu%rotz_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%rotz_varid), "netcdf_initialize_output nf90_def_var rotz_varid"  )
         end if

         ! if (param%ltides) then
         !    call check( nf90_def_var(nciu%id, nciu%k2_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%k2_varid), "netcdf_initialize_output nf90_def_var k2_varid"  )
         !    call check( nf90_def_var(nciu%id, nciu%q_varname, nciu%out_type, [nciu%id_dimid, nciu%time_dimid], nciu%Q_varid), "netcdf_initialize_output nf90_def_var Q_varid"  )
         ! end if

         if (param%lenergy) then
            call check( nf90_def_var(nciu%id, nciu%ke_orb_varname, nciu%out_type, nciu%time_dimid, nciu%KE_orb_varid), "netcdf_initialize_output nf90_def_var KE_orb_varid"  )
            call check( nf90_def_var(nciu%id, nciu%ke_spin_varname, nciu%out_type, nciu%time_dimid, nciu%KE_spin_varid), "netcdf_initialize_output nf90_def_var KE_spin_varid"  )
            call check( nf90_def_var(nciu%id, nciu%pe_varname, nciu%out_type, nciu%time_dimid, nciu%PE_varid), "netcdf_initialize_output nf90_def_var PE_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_orbx_varname, nciu%out_type, nciu%time_dimid, nciu%L_orbx_varid), "netcdf_initialize_output nf90_def_var L_orbx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_orby_varname, nciu%out_type, nciu%time_dimid, nciu%L_orby_varid), "netcdf_initialize_output nf90_def_var L_orby_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_orbz_varname, nciu%out_type, nciu%time_dimid, nciu%L_orbz_varid), "netcdf_initialize_output nf90_def_var L_orbz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_spinx_varname, nciu%out_type, nciu%time_dimid, nciu%L_spinx_varid), "netcdf_initialize_output nf90_def_var L_spinx_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_spiny_varname, nciu%out_type, nciu%time_dimid, nciu%L_spiny_varid), "netcdf_initialize_output nf90_def_var L_spiny_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_spinz_varname, nciu%out_type, nciu%time_dimid, nciu%L_spinz_varid), "netcdf_initialize_output nf90_def_var L_spinz_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_escapex_varname, nciu%out_type, nciu%time_dimid, nciu%L_escapex_varid), "netcdf_initialize_output nf90_def_var L_escapex_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_escapey_varname, nciu%out_type, nciu%time_dimid, nciu%L_escapey_varid), "netcdf_initialize_output nf90_def_var L_escapey_varid"  )
            call check( nf90_def_var(nciu%id, nciu%l_escapez_varname, nciu%out_type, nciu%time_dimid, nciu%L_escapez_varid), "netcdf_initialize_output nf90_def_var L_escapez_varid"  )
            call check( nf90_def_var(nciu%id, nciu%ecollisions_varname, nciu%out_type, nciu%time_dimid, nciu%Ecollisions_varid), "netcdf_initialize_output nf90_def_var Ecollisions_varid"  )
            call check( nf90_def_var(nciu%id, nciu%euntracked_varname, nciu%out_type, nciu%time_dimid, nciu%Euntracked_varid), "netcdf_initialize_output nf90_def_var Euntracked_varid"  )
            call check( nf90_def_var(nciu%id, nciu%gmescape_varname, nciu%out_type, nciu%time_dimid, nciu%GMescape_varid), "netcdf_initialize_output nf90_def_var GMescape_varid"  )
         end if

         call check( nf90_def_var(nciu%id, nciu%j2rp2_varname, nciu%out_type, nciu%time_dimid, nciu%j2rp2_varid), "netcdf_initialize_output nf90_def_var j2rp2_varid"  )
         call check( nf90_def_var(nciu%id, nciu%j4rp4_varname, nciu%out_type, nciu%time_dimid, nciu%j4rp4_varid), "netcdf_initialize_output nf90_def_var j4rp4_varid"  )


         ! Set fill mode to NaN for all variables
         call check( nf90_inquire(nciu%id, nVariables=nvar), "netcdf_initialize_output nf90_inquire nVariables"  )
         do varid = 1, nvar
            call check( nf90_inquire_variable(nciu%id, varid, xtype=vartype, ndims=ndims), "netcdf_initialize_output nf90_inquire_variable"  )
            select case(vartype)
            case(NF90_INT)
               call check( nf90_def_var_fill(nciu%id, varid, 0, NF90_FILL_INT), "netcdf_initialize_output nf90_def_var_fill NF90_INT"  )
            case(NF90_FLOAT)
               call check( nf90_def_var_fill(nciu%id, varid, 0, sfill), "netcdf_initialize_output nf90_def_var_fill NF90_FLOAT"  )
            case(NF90_DOUBLE)
               call check( nf90_def_var_fill(nciu%id, varid, 0, dfill), "netcdf_initialize_output nf90_def_var_fill NF90_DOUBLE"  )
            case(NF90_CHAR)
               call check( nf90_def_var_fill(nciu%id, varid, 0, 0), "netcdf_initialize_output nf90_def_var_fill NF90_CHAR"  )
            end select
         end do

         ! Take the file out of define mode
         call check( nf90_enddef(nciu%id), "netcdf_initialize_output nf90_enddef"  )

         call check( nf90_put_var(nciu%id, nciu%space_varid, ["x","y","z"], start=[1], count=[3]), "netcdf_initialize_output nf90_put_var space"  )

      end associate
      return

      667 continue
      write(*,*) "Error creating NetCDF output file. " // trim(adjustl(errmsg))
      call util_exit(FAILURE)
   end subroutine netcdf_initialize_output


   module subroutine netcdf_open(self, param, readonly)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Opens a NetCDF file and does the variable inquiries to activate variable ids
      implicit none
      ! Arguments
      class(netcdf_parameters),   intent(inout) :: self     !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters), intent(in)    :: param    !! Current run configuration parameters
      logical, optional,          intent(in)    :: readonly !! Logical flag indicating that this should be open read only
      ! Internals
      integer(I4B) :: mode, status
      character(len=STRMAX) :: errmsg

      mode = NF90_WRITE
      if (present(readonly)) then
         if (readonly) mode = NF90_NOWRITE
      end if

      write(errmsg,*) "netcdf_open nf90_open ",trim(adjustl(param%outfile))
      call check( nf90_open(param%outfile, mode, self%id), errmsg)

      ! Dimensions
      call check( nf90_inq_dimid(self%id, self%time_dimname, self%time_dimid), "netcdf_open nf90_inq_dimid time_dimid"  )
      call check( nf90_inq_dimid(self%id, self%id_dimname, self%id_dimid), "netcdf_open nf90_inq_dimid id_dimid"  )
      call check( nf90_inq_dimid(self%id, self%space_dimname, self%space_dimid), "netcdf_open nf90_inq_dimid space_dimid"  )
      call check( nf90_inq_dimid(self%id, self%str_dimname, self%str_dimid), "netcdf_open nf90_inq_dimid str_dimid"  )

      ! Dimension coordinates
      call check( nf90_inq_varid(self%id, self%time_dimname, self%time_varid), "netcdf_open nf90_inq_varid time_varid" )
      call check( nf90_inq_varid(self%id, self%id_dimname, self%id_varid), "netcdf_open nf90_inq_varid id_varid" )
      call check( nf90_inq_varid(self%id, self%space_dimname, self%space_varid), "netcdf_open nf90_inq_varid space_varid" )

      ! Required Variables
      call check( nf90_inq_varid(self%id, self%name_varname, self%name_varid), "netcdf_open nf90_inq_varid name_varid" )
      call check( nf90_inq_varid(self%id, self%ptype_varname, self%ptype_varid), "netcdf_open nf90_inq_varid ptype_varid" )
      call check( nf90_inq_varid(self%id, self%gmass_varname, self%Gmass_varid), "netcdf_open nf90_inq_varid Gmass_varid" )

      if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
         call check( nf90_inq_varid(self%id, self%xhx_varname, self%xhx_varid), "netcdf_open nf90_inq_varid xhx_varid" )
         call check( nf90_inq_varid(self%id, self%xhy_varname, self%xhy_varid), "netcdf_open nf90_inq_varid xhy_varid" )
         call check( nf90_inq_varid(self%id, self%xhz_varname, self%xhz_varid), "netcdf_open nf90_inq_varid xhz_varid" )
         call check( nf90_inq_varid(self%id, self%vhx_varname, self%vhx_varid), "netcdf_open nf90_inq_varid vhx_varid" )
         call check( nf90_inq_varid(self%id, self%vhy_varname, self%vhy_varid), "netcdf_open nf90_inq_varid vhy_varid" )
         call check( nf90_inq_varid(self%id, self%vhz_varname, self%vhz_varid), "netcdf_open nf90_inq_varid vhz_varid" )

         if (param%lgr) then
            !! check if pseudovelocity vectors exist in this file. If they are, set the correct flag so we know whe should not do the conversion.
            status = nf90_inq_varid(self%id, self%gr_pseudo_vhx_varname, self%gr_pseudo_vhx_varid)
            self%lpseudo_vel_exists = (status == nf90_noerr)
            if (self%lpseudo_vel_exists) then
               status = nf90_inq_varid(self%id, self%gr_pseudo_vhy_varname, self%gr_pseudo_vhy_varid)
               self%lpseudo_vel_exists = (status == nf90_noerr)
               if (self%lpseudo_vel_exists) then
                  status = nf90_inq_varid(self%id, self%gr_pseudo_vhz_varname, self%gr_pseudo_vhz_varid)
                  self%lpseudo_vel_exists = (status == nf90_noerr)
               end if
            end if
            if (.not.self%lpseudo_vel_exists) then
               write(*,*) "Warning! Pseudovelocity not found in input file for GR enabled run. If this is a restarted run, bit-identical trajectories are not guarunteed!"
            end if

         end if
      end if

      if ((param%out_form == "EL") .or. (param%out_form == "XVEL")) then
         call check( nf90_inq_varid(self%id, self%a_varname, self%a_varid), "netcdf_open nf90_inq_varid a_varid" )
         call check( nf90_inq_varid(self%id, self%e_varname, self%e_varid), "netcdf_open nf90_inq_varid e_varid" )
         call check( nf90_inq_varid(self%id, self%inc_varname, self%inc_varid), "netcdf_open nf90_inq_varid inc_varid" )
         call check( nf90_inq_varid(self%id, self%capom_varname, self%capom_varid), "netcdf_open nf90_inq_varid capom_varid" )
         call check( nf90_inq_varid(self%id, self%omega_varname, self%omega_varid), "netcdf_open nf90_inq_varid omega_varid" )
         call check( nf90_inq_varid(self%id, self%capm_varname, self%capm_varid), "netcdf_open nf90_inq_varid capm_varid" )
      end if

      if (param%lclose) then
         call check( nf90_inq_varid(self%id, self%radius_varname, self%radius_varid), "netcdf_open nf90_inq_varid radius_varid" )
      end if 

      if (param%lrotation) then
         call check( nf90_inq_varid(self%id, self%ip1_varname, self%Ip1_varid), "netcdf_open nf90_inq_varid Ip1_varid" )
         call check( nf90_inq_varid(self%id, self%ip2_varname, self%Ip2_varid), "netcdf_open nf90_inq_varid Ip2_varid" )
         call check( nf90_inq_varid(self%id, self%ip3_varname, self%Ip3_varid), "netcdf_open nf90_inq_varid Ip3_varid" )
         call check( nf90_inq_varid(self%id, self%rotx_varname, self%rotx_varid), "netcdf_open nf90_inq_varid rotx_varid" )
         call check( nf90_inq_varid(self%id, self%roty_varname, self%roty_varid), "netcdf_open nf90_inq_varid roty_varid" )
         call check( nf90_inq_varid(self%id, self%rotz_varname, self%rotz_varid), "netcdf_open nf90_inq_varid rotz_varid" )
      end if

      ! if (param%ltides) then
      !    call check( nf90_inq_varid(self%id, self%k2_varname, self%k2_varid), "netcdf_open nf90_inq_varid k2_varid" )
      !    call check( nf90_inq_varid(self%id, self%q_varname, self%Q_varid), "netcdf_open nf90_inq_varid Q_varid" )
      ! end if

      ! Optional Variables
      if (param%lrhill_present) then
         status = nf90_inq_varid(self%id, self%rhill_varname, self%rhill_varid)
         if (status /= nf90_noerr) write(*,*) "Warning! RHILL variable not set in input file. Calculating."
      end if

      ! Optional variables The User Doesn't Need to Know About
      status = nf90_inq_varid(self%id, self%npl_varname, self%npl_varid)
      status = nf90_inq_varid(self%id, self%ntp_varname, self%ntp_varid)
      status = nf90_inq_varid(self%id, self%status_varname, self%status_varid)
      status = nf90_inq_varid(self%id, self%j2rp2_varname, self%j2rp2_varid)
      status = nf90_inq_varid(self%id, self%j4rp4_varname, self%j4rp4_varid)

      if (param%integrator == SYMBA) then
         status = nf90_inq_varid(self%id, self%nplm_varname, self%nplm_varid)
      end if

      if (param%lclose) then
         status = nf90_inq_varid(self%id, self%origin_type_varname, self%origin_type_varid)
         status = nf90_inq_varid(self%id, self%origin_time_varname, self%origin_time_varid)
         status = nf90_inq_varid(self%id, self%origin_xhx_varname, self%origin_xhx_varid)
         status = nf90_inq_varid(self%id, self%origin_xhy_varname, self%origin_xhy_varid)
         status = nf90_inq_varid(self%id, self%origin_xhz_varname, self%origin_xhz_varid)
         status = nf90_inq_varid(self%id, self%origin_vhx_varname, self%origin_vhx_varid)
         status = nf90_inq_varid(self%id, self%origin_vhy_varname, self%origin_vhy_varid)
         status = nf90_inq_varid(self%id, self%origin_vhz_varname, self%origin_vhz_varid)
         status = nf90_inq_varid(self%id, self%collision_id_varname, self%collision_id_varid)
         status = nf90_inq_varid(self%id, self%discard_time_varname, self%discard_time_varid)
         status = nf90_inq_varid(self%id, self%discard_xhx_varname, self%discard_xhx_varid)
         status = nf90_inq_varid(self%id, self%discard_xhy_varname, self%discard_xhy_varid)
         status = nf90_inq_varid(self%id, self%discard_xhz_varname, self%discard_xhz_varid)
         status = nf90_inq_varid(self%id, self%discard_vhx_varname, self%discard_vhx_varid)
         status = nf90_inq_varid(self%id, self%discard_vhy_varname, self%discard_vhy_varid)
         status = nf90_inq_varid(self%id, self%discard_vhz_varname, self%discard_vhz_varid)
         status = nf90_inq_varid(self%id, self%discard_body_id_varname, self%discard_body_id_varid)
      end if

      if (param%lenergy) then
         status = nf90_inq_varid(self%id, self%ke_orb_varname, self%KE_orb_varid)
         status = nf90_inq_varid(self%id, self%ke_spin_varname, self%KE_spin_varid)
         status = nf90_inq_varid(self%id, self%pe_varname, self%PE_varid)
         status = nf90_inq_varid(self%id, self%l_orbx_varname, self%L_orbx_varid)
         status = nf90_inq_varid(self%id, self%l_orby_varname, self%L_orby_varid)
         status = nf90_inq_varid(self%id, self%l_orbz_varname, self%L_orbz_varid)
         status = nf90_inq_varid(self%id, self%l_spinx_varname, self%L_spinx_varid)
         status = nf90_inq_varid(self%id, self%l_spiny_varname, self%L_spiny_varid)
         status = nf90_inq_varid(self%id, self%l_spinz_varname, self%L_spinz_varid)
         status = nf90_inq_varid(self%id, self%l_escapex_varname, self%L_escapex_varid)
         status = nf90_inq_varid(self%id, self%l_escapey_varname, self%L_escapey_varid)
         status = nf90_inq_varid(self%id, self%l_escapez_varname, self%L_escapez_varid)
         status = nf90_inq_varid(self%id, self%ecollisions_varname, self%Ecollisions_varid)
         status = nf90_inq_varid(self%id, self%euntracked_varname, self%Euntracked_varid)
         status = nf90_inq_varid(self%id, self%gmescape_varname, self%GMescape_varid)
      end if

      return
   end subroutine netcdf_open


   module function netcdf_read_frame_system(self, nciu, param) result(ierr)
      !! author: The Purdue Swiftest Team - David A. Minton, Carlisle A. Wishard, Jennifer L.L. Pouplin, and Jacob R. Elliott
      !!
      !! Read a frame (header plus records for each massive body and active test particle) from an output binary file
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(inout) :: self  !! Swiftest system object
      class(netcdf_parameters),     intent(inout) :: nciu    !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters),   intent(inout) :: param !! Current run configuration parameters 
      ! Return
      integer(I4B)                                :: ierr  !! Error code: returns 0 if the read is successful
      ! Internals
      integer(I4B)                              :: tslot, idmax, npl_check, ntp_check, nplm_check, t_max, str_max, status
      real(DP), dimension(:), allocatable       :: rtemp
      integer(I4B), dimension(:), allocatable   :: itemp
      logical, dimension(:), allocatable        :: validmask, tpmask, plmask

      call nciu%open(param, readonly=.true.)
      call self%read_hdr(nciu, param)

      associate(cb => self%cb, pl => self%pl, tp => self%tp, npl => self%pl%nbody, ntp => self%tp%nbody)

         call pl%setup(npl, param)
         call tp%setup(ntp, param)

         tslot = param%ioutput + 1

         call check( nf90_inquire_dimension(nciu%id, nciu%id_dimid, len=idmax), "netcdf_read_frame_system nf90_inquire_dimension id_dimid"  )
         allocate(rtemp(idmax))
         allocate(itemp(idmax))
         allocate(validmask(idmax))
         allocate(tpmask(idmax))
         allocate(plmask(idmax))
         call check( nf90_inquire_dimension(nciu%id, nciu%time_dimid, len=t_max), "netcdf_read_frame_system nf90_inquire_dimension time_dimid"  )
         call check( nf90_inquire_dimension(nciu%id, nciu%str_dimid, len=str_max), "netcdf_read_frame_system nf90_inquire_dimension str_dimid"  )

         ! First filter out only the id slots that contain valid bodies
         if (param%in_form == "XV") then
            call check( nf90_get_var(nciu%id, nciu%xhx_varid, rtemp(:), start=[1, tslot]), "netcdf_read_frame_system filter pass nf90_getvar xhx_varid"  )
         else
            call check( nf90_get_var(nciu%id, nciu%a_varid, rtemp(:), start=[1, tslot]), "netcdf_read_frame_system filter pass nf90_getvar a_varid"  )
         end if

         validmask(:) = rtemp(:) == rtemp(:)

         ! Next, filter only bodies that don't have mass (test particles)
         call check( nf90_get_var(nciu%id, nciu%Gmass_varid, rtemp(:), start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Gmass_varid"  )
         plmask(:) = rtemp(:) == rtemp(:)  .and. validmask(:)
         tpmask(:) = .not. plmask(:) .and. validmask(:)
         plmask(1) = .false. ! This is the central body

         ! Check to make sure the number of bodies is correct
         npl_check = count(plmask(:))
         ntp_check = count(tpmask(:))

         if (npl_check /= npl) then
            write(*,*) "Error reading in NetCDF file: The recorded value of npl does not match the number of active massive bodies"
            call util_exit(failure)
         end if

         if (ntp_check /= ntp) then
            write(*,*) "Error reading in NetCDF file: The recorded value of ntp does not match the number of active test particles"
            call util_exit(failure)
         end if

         select type (pl)
         class is (symba_pl)
            select type (param)
            class is (symba_parameters)
               nplm_check = count(pack(rtemp,plmask) > param%GMTINY )
               if (nplm_check /= pl%nplm) then
                  write(*,*) "Error reading in NetCDF file: The recorded value of nplm does not match the number of active fully interacting massive bodies"
                  call util_exit(failure)
               end if
            end select
         end select

         ! Now read in each variable and split the outputs by body type
         if ((param%in_form == "XV") .or. (param%in_form == "XVEL")) then
            call check( nf90_get_var(nciu%id, nciu%xhx_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar xhx_varid"  )
            if (npl > 0) pl%xh(1,:) = pack(rtemp, plmask)
            if (ntp > 0) tp%xh(1,:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%xhy_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar xhy_varid"  )
            if (npl > 0) pl%xh(2,:) = pack(rtemp, plmask)
            if (ntp > 0) tp%xh(2,:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%xhz_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar xhz_varid"  )
            if (npl > 0) pl%xh(3,:) = pack(rtemp, plmask)
            if (ntp > 0) tp%xh(3,:) = pack(rtemp, tpmask)

            if (param%lgr .and. nciu%lpseudo_vel_exists) then
               call check( nf90_get_var(nciu%id, nciu%gr_pseudo_vhx_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar gr_pseudo_vhx_varid"  )
               if (npl > 0) pl%vh(1,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(1,:) = pack(rtemp, tpmask)

               call check( nf90_get_var(nciu%id, nciu%gr_pseudo_vhy_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar gr_pseudo_vhy_varid"  )
               if (npl > 0) pl%vh(2,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(2,:) = pack(rtemp, tpmask)

               call check( nf90_get_var(nciu%id, nciu%gr_pseudo_vhz_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar gr_pseudo_vhz_varid"  )
               if (npl > 0) pl%vh(3,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(3,:) = pack(rtemp, tpmask)
            else
               call check( nf90_get_var(nciu%id, nciu%vhx_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar vhx_varid"  )
               if (npl > 0) pl%vh(1,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(1,:) = pack(rtemp, tpmask)

               call check( nf90_get_var(nciu%id, nciu%vhy_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar vhy_varid"  )
               if (npl > 0) pl%vh(2,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(2,:) = pack(rtemp, tpmask)

               call check( nf90_get_var(nciu%id, nciu%vhz_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar vhz_varid"  )
               if (npl > 0) pl%vh(3,:) = pack(rtemp, plmask)
               if (ntp > 0) tp%vh(3,:) = pack(rtemp, tpmask)
            end if
         end if

         if ((param%in_form == "EL")  .or. (param%in_form == "XVEL")) then
            call check( nf90_get_var(nciu%id, nciu%a_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar a_varid"  )
            if (.not.allocated(pl%a)) allocate(pl%a(npl))
            if (.not.allocated(tp%a)) allocate(tp%a(ntp))
            if (npl > 0) pl%a(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%a(:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%e_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar e_varid"  )
            if (.not.allocated(pl%e)) allocate(pl%e(npl))
            if (.not.allocated(tp%e)) allocate(tp%e(ntp))
            if (npl > 0) pl%e(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%e(:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%inc_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar inc_varid"  )
            rtemp = rtemp * DEG2RAD
            if (.not.allocated(pl%inc)) allocate(pl%inc(npl))
            if (.not.allocated(tp%inc)) allocate(tp%inc(ntp))
            if (npl > 0) pl%inc(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%inc(:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%capom_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar capom_varid"  )
            rtemp = rtemp * DEG2RAD
            if (.not.allocated(pl%capom)) allocate(pl%capom(npl))
            if (.not.allocated(tp%capom)) allocate(tp%capom(ntp))
            if (npl > 0) pl%capom(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%capom(:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%omega_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar omega_varid"  )
            rtemp = rtemp * DEG2RAD
            if (.not.allocated(pl%omega)) allocate(pl%omega(npl))
            if (.not.allocated(tp%omega)) allocate(tp%omega(ntp))
            if (npl > 0) pl%omega(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%omega(:) = pack(rtemp, tpmask)

            call check( nf90_get_var(nciu%id, nciu%capm_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar capm_varid"  )
            rtemp = rtemp * DEG2RAD
            if (.not.allocated(pl%capm)) allocate(pl%capm(npl))
            if (.not.allocated(tp%capm)) allocate(tp%capm(ntp))
            if (npl > 0) pl%capm(:) = pack(rtemp, plmask)
            if (ntp > 0) tp%capm(:) = pack(rtemp, tpmask)

         end if
      
         call check( nf90_get_var(nciu%id, nciu%Gmass_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Gmass_varid"  )
         cb%Gmass = rtemp(1)
         cb%mass = cb%Gmass / param%GU

         ! Set initial central body mass for Helio bookkeeping
         select type(cb)
            class is (symba_cb)
               cb%GM0 = cb%Gmass
         end select
            

         if (npl > 0) then
            pl%Gmass(:) = pack(rtemp, plmask)
            pl%mass(:) = pl%Gmass(:) / param%GU

            if (param%lrhill_present) then 
               call check( nf90_get_var(nciu%id, nciu%rhill_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar rhill_varid"  )
               pl%rhill(:) = pack(rtemp, plmask)
            end if
         end if

         if (param%lclose) then
            call check( nf90_get_var(nciu%id, nciu%radius_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar radius_varid"  )
            cb%radius = rtemp(1)

            ! Set initial central body radius for SyMBA bookkeeping
            select type(cb)
               class is (symba_cb)
                  cb%R0 = cb%radius
            end select
            if (npl > 0) pl%radius(:) = pack(rtemp, plmask)
         else
            cb%radius = param%rmin
            if (npl > 0) pl%radius(:) = 0.0_DP
         end if

         if (param%lrotation) then
            call check( nf90_get_var(nciu%id, nciu%Ip1_varid,  rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Ip1_varid"  )
            cb%Ip(1) = rtemp(1)
            if (npl > 0) pl%Ip(1,:) = pack(rtemp, plmask)

            call check( nf90_get_var(nciu%id, nciu%Ip2_varid,  rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Ip2_varid"  )
            cb%Ip(2) = rtemp(1)
            if (npl > 0) pl%Ip(2,:) = pack(rtemp, plmask)

            call check( nf90_get_var(nciu%id, nciu%Ip3_varid,  rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Ip3_varid"  )
            cb%Ip(3) = rtemp(1)
            if (npl > 0) pl%Ip(3,:) = pack(rtemp, plmask)

            call check( nf90_get_var(nciu%id, nciu%rotx_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar rotx_varid"  )
            cb%rot(1) = rtemp(1)
            if (npl > 0) pl%rot(1,:) = pack(rtemp, plmask)

            call check( nf90_get_var(nciu%id, nciu%roty_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar roty_varid"  )
            cb%rot(2) = rtemp(1)
            if (npl > 0) pl%rot(2,:) = pack(rtemp, plmask)

            call check( nf90_get_var(nciu%id, nciu%rotz_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar rotz_varid"  )
            cb%rot(3) = rtemp(1)
            if (npl > 0) pl%rot(3,:) = pack(rtemp, plmask)

            ! Set initial central body angular momentum for Helio bookkeeping
            select type(cb)
               class is (symba_cb)
                  cb%L0(:) = cb%Ip(3) * cb%GM0 * cb%R0**2 * cb%rot(:)         
            end select
         end if

         ! if (param%ltides) then
         !    call check( nf90_get_var(nciu%id, nciu%k2_varid, rtemp, start=[1, tslot]), "netcdf_read_frame_system nf90_getvar k2_varid"  )
         !    cb%k2 = rtemp(1)
         !    if (npl > 0) pl%k2(:) = pack(rtemp, plmask)

         !    call check( nf90_get_var(nciu%id, nciu%Q_varid,  rtemp,  start=[1, tslot]), "netcdf_read_frame_system nf90_getvar Q_varid"  )
         !    cb%Q = rtemp(1)
         !    if (npl > 0) pl%Q(:) = pack(rtemp, plmask)
         ! end if

         status = nf90_inq_varid(nciu%id, nciu%j2rp2_varname, nciu%j2rp2_varid)
         if (status == nf90_noerr) then
            call check( nf90_get_var(nciu%id, nciu%j2rp2_varid, cb%j2rp2, start=[tslot]), "netcdf_read_frame_system nf90_getvar j2rp2_varid"  )
         else 
            cb%j2rp2 = 0.0_DP
         end if

         status = nf90_inq_varid(nciu%id, nciu%j4rp4_varname, nciu%j4rp4_varid)   
         if (status == nf90_noerr) then      
            call check( nf90_get_var(nciu%id, nciu%j4rp4_varid, cb%j4rp4, start=[tslot]), "netcdf_read_frame_system nf90_getvar j4rp4_varid"  )
         else 
            cb%j4rp4 = 0.0_DP
         end if

         call self%read_particle_info(nciu, param, plmask, tpmask) 

         if (param%in_form == "EL") then
            call pl%el2xv(cb)
            call tp%el2xv(cb)
         end if
         ! if this is a GR-enabled run, check to see if we got the pseudovelocities in. Otherwise, we'll need to generate them.
         if (param%lgr .and. .not.(nciu%lpseudo_vel_exists)) then
            call pl%set_mu(cb)
            call tp%set_mu(cb)
            call pl%v2pv(param)
            call tp%v2pv(param)
         end if
         
      end associate

      call nciu%close()

      ierr = 0
      return

      667 continue
      write(*,*) "Error reading system frame in netcdf_read_frame_system"

   end function netcdf_read_frame_system


   module subroutine netcdf_read_hdr_system(self, nciu, param) 
      !! author: David A. Minton
      !!
      !! Reads header information (variables that change with time, but not particle id). 
      !! This subroutine significantly improves the output over the original binary file, allowing us to track energy, momentum, and other quantities that 
      !! previously were handled as separate output files.
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(inout) :: self  !! Swiftest nbody system object
      class(netcdf_parameters),     intent(inout) :: nciu    !! Parameters used to for writing a NetCDF dataset to file
      class(swiftest_parameters),   intent(inout) :: param !! Current run configuration parameters
      ! Internals
      integer(I4B) :: tslot, status, idmax
      real(DP), dimension(:), allocatable       :: gmtemp
      logical, dimension(:), allocatable        :: plmask, tpmask, plmmask


      tslot = param%ioutput + 1
      call check( nf90_inquire_dimension(nciu%id, nciu%id_dimid, len=idmax), "netcdf_read_frame_system nf90_inquire_dimension id_dimid"  )
      call check( nf90_get_var(nciu%id, nciu%time_varid, self%t, start=[tslot]), "netcdf_read_hdr_system nf90_getvar time_varid"  )

      allocate(gmtemp(idmax))
      allocate(tpmask(idmax))
      allocate(plmask(idmax))
      allocate(plmmask(idmax))

      call check( nf90_get_var(nciu%id, nciu%Gmass_varid, gmtemp, start=[1,1]), "netcdf_read_frame_system nf90_getvar Gmass_varid"  )

      plmask(:) = gmtemp(:) == gmtemp(:)
      tpmask(:) = .not. plmask(:)
      plmask(1) = .false. ! This is the central body
      select type (param)
      class is (symba_parameters)
         plmmask(:) = plmask(:)
         where(plmask(:))
            plmmask(:) = gmtemp(:) > param%GMTINY
         endwhere
      end select

      status = nf90_inq_varid(nciu%id, nciu%npl_varname, nciu%npl_varid)
      if (status == nf90_noerr) then
         call check( nf90_get_var(nciu%id, nciu%npl_varid,  self%pl%nbody, start=[tslot]), "netcdf_read_hdr_system nf90_getvar npl_varid"  )
      else
         self%pl%nbody = count(plmask(:))
      end if

      status = nf90_inq_varid(nciu%id, nciu%ntp_varname, nciu%ntp_varid)
      if (status == nf90_noerr) then
         call check( nf90_get_var(nciu%id, nciu%ntp_varid,  self%tp%nbody, start=[tslot]), "netcdf_read_hdr_system nf90_getvar ntp_varid"  )
      else
         self%tp%nbody = count(tpmask(:))
      end if

      if (param%integrator == SYMBA) then
         status = nf90_inq_varid(nciu%id, nciu%nplm_varname, nciu%nplm_varid)
         select type(pl => self%pl)
         class is (symba_pl)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%nplm_varid,  pl%nplm, start=[tslot]), "netcdf_read_hdr_system nf90_getvar nplm_varid"  )
            else
               pl%nplm = count(plmmask(:))
            end if
         end select
      end if

      if (param%lenergy) then
         status = nf90_inq_varid(nciu%id, nciu%ke_orb_varname, nciu%KE_orb_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%KE_orb_varid,      self%ke_orbit,    start=[tslot]), "netcdf_read_hdr_system nf90_getvar KE_orb_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%ke_spin_varname, nciu%KE_spin_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%KE_spin_varid,     self%ke_spin,     start=[tslot]), "netcdf_read_hdr_system nf90_getvar KE_spin_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%pe_varname, nciu%PE_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%PE_varid,          self%pe,          start=[tslot]), "netcdf_read_hdr_system nf90_getvar PE_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_orbx_varname, nciu%L_orbx_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_orbx_varid,      self%Lorbit(1),   start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_orbx_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_orby_varname, nciu%L_orby_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_orby_varid,      self%Lorbit(2),   start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_orby_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_orbz_varname, nciu%L_orbz_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_orbz_varid,      self%Lorbit(3),   start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_orbz_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_spinx_varname, nciu%L_spinx_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_spinx_varid,     self%Lspin(1),    start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_spinx_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_spiny_varname, nciu%L_spiny_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_spiny_varid,     self%Lspin(2),    start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_spiny_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_spinz_varname, nciu%L_spinz_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_spinz_varid,     self%Lspin(3),    start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_spinz_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_escapex_varname, nciu%L_escapex_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_escapex_varid,   self%Lescape(1),  start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_escapex_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_escapey_varname, nciu%L_escapey_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_escapey_varid,   self%Lescape(2),  start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_escapey_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%l_escapez_varname, nciu%L_escapez_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%L_escapez_varid,   self%Lescape(3),  start=[tslot]), "netcdf_read_hdr_system nf90_getvar L_escapez_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%ecollisions_varname, nciu%Ecollisions_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%Ecollisions_varid, self%Ecollisions, start=[tslot]), "netcdf_read_hdr_system nf90_getvar Ecollisions_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%euntracked_varname, nciu%Euntracked_varid)
         if (status == nf90_noerr) call check( nf90_get_var(nciu%id, nciu%Euntracked_varid,  self%Euntracked,  start=[tslot]), "netcdf_read_hdr_system nf90_getvar Euntracked_varid"  )
         status = nf90_inq_varid(nciu%id, nciu%gmescape_varname, nciu%GMescape_varid)
         if (status == nf90_noerr)  call check( nf90_get_var(nciu%id, nciu%GMescape_varid,    self%GMescape,    start=[tslot]), "netcdf_read_hdr_system nf90_getvar GMescape_varid"  )
      end if

      return
   end subroutine netcdf_read_hdr_system


   module subroutine netcdf_read_particle_info_system(self, nciu, param, plmask, tpmask)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Reads particle information metadata from file
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(inout) :: self   !! Swiftest nbody system object
      class(netcdf_parameters),     intent(inout) :: nciu     !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters),   intent(inout) :: param  !! Current run configuration parameters
      logical, dimension(:),        intent(in)    :: plmask !! Logical array indicating which index values belong to massive bodies
      logical, dimension(:),        intent(in)    :: tpmask !! Logical array indicating which index values belong to test particles
      ! Internals
      integer(I4B)                                :: i, idmax, status
      real(DP), dimension(:), allocatable         :: rtemp
      real(DP), dimension(:,:), allocatable       :: rtemp_arr
      integer(I4B), dimension(:), allocatable     :: itemp
      character(len=NAMELEN), dimension(:), allocatable :: ctemp
      integer(I4B), dimension(:), allocatable     :: plind, tpind

      ! This string of spaces of length NAMELEN is used to clear out any old data left behind inside the string variables
      idmax = size(plmask)
      allocate(rtemp(idmax))
      allocate(rtemp_arr(NDIM,idmax))
      allocate(itemp(idmax))
      allocate(ctemp(idmax))

      associate(cb => self%cb, pl => self%pl, tp => self%tp, npl => self%pl%nbody, ntp => self%tp%nbody)

         if (npl > 0) then
            pl%status(:) = ACTIVE
            pl%lmask(:) = .true.
            do i = 1, npl
               call pl%info(i)%set_value(status="ACTIVE")
            end do
            allocate(plind(npl))
            plind(:) = pack([(i, i = 1, idmax)], plmask(:))
         end if
         if (ntp > 0) then
            tp%status(:) = ACTIVE
            tp%lmask(:) = .true.
            do i = 1, ntp
               call tp%info(i)%set_value(status="ACTIVE")
            end do
            allocate(tpind(ntp))
            tpind(:) = pack([(i, i = 1, idmax)], tpmask(:))
         end if

         call check( nf90_get_var(nciu%id, nciu%id_varid, itemp), "netcdf_read_particle_info_system nf90_getvar id_varid"  )
         cb%id = itemp(1)
         pl%id(:) = pack(itemp, plmask)
         tp%id(:) = pack(itemp, tpmask)

         call check( nf90_get_var(nciu%id, nciu%name_varid, ctemp, count=[NAMELEN, idmax]), "netcdf_read_particle_info_system nf90_getvar name_varid"  )
         call cb%info%set_value(name=ctemp(1))
         do i = 1, npl
            call pl%info(i)%set_value(name=ctemp(plind(i)))
         end do
         do i = 1, ntp
            call tp%info(i)%set_value(name=ctemp(tpind(i)))
         end do

         call check( nf90_get_var(nciu%id, nciu%ptype_varid, ctemp, count=[NAMELEN, idmax]), "netcdf_read_particle_info_system nf90_getvar ptype_varid"  )
         call cb%info%set_value(particle_type=ctemp(1))
         do i = 1, npl
            call pl%info(i)%set_value(particle_type=ctemp(plind(i)))
         end do
         do i = 1, ntp
            call tp%info(i)%set_value(particle_type=ctemp(tpind(i)))
         end do

         status = nf90_inq_varid(nciu%id, nciu%status_varname, nciu%status_varid) 
         if (status == nf90_noerr) then
            call check( nf90_get_var(nciu%id, nciu%status_varid, ctemp, count=[NAMELEN, idmax]), "netcdf_read_particle_info_system nf90_getvar status_varid")
            call cb%info%set_value(status=ctemp(1))
         else
            call cb%info%set_value(status="ACTIVE")
         end if
         do i = 1, npl
            call pl%info(i)%set_value(status=ctemp(plind(i)))
         end do
         do i = 1, ntp
            call tp%info(i)%set_value(status=ctemp(tpind(i)))
         end do

         if (param%lclose) then

            status = nf90_inq_varid(nciu%id, nciu%origin_type_varname, nciu%origin_type_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_type_varid, ctemp, count=[NAMELEN, idmax]), "netcdf_read_particle_info_system nf90_getvar origin_type_varid"  )
            else
               ctemp = "Initial Conditions"
            end if

            call cb%info%set_value(origin_type=ctemp(1))
            do i = 1, npl
               call pl%info(i)%set_value(origin_type=ctemp(plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(origin_type=ctemp(tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%origin_time_varname, nciu%origin_time_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_time_varid, rtemp), "netcdf_read_particle_info_system nf90_getvar origin_time_varid"  )
            else
               rtemp = param%t0
            end if

            call cb%info%set_value(origin_time=rtemp(1))
            do i = 1, npl
               call pl%info(i)%set_value(origin_time=rtemp(plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(origin_time=rtemp(tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%origin_xhx_varname, nciu%origin_xhx_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_xhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar origin_xhx_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%xhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar xhx_varid"  )
            else 
               rtemp_arr(1,:) = 0._DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%origin_xhy_varname, nciu%origin_xhy_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_xhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar origin_xhy_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%xhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar xhx_varid"  )
            else 
               rtemp_arr(2,:) = 0._DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%origin_xhz_varname, nciu%origin_xhz_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_xhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar origin_xhz_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%xhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar xhz_varid"  )
            else
               rtemp_arr(3,:) = 0._DP
            end if 

            do i = 1, npl
               call pl%info(i)%set_value(origin_xh=rtemp_arr(:,plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(origin_xh=rtemp_arr(:,tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%origin_vhx_varname, nciu%origin_vhx_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_vhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar origin_vhx_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%vhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar vhx_varid"  )
            else
               rtemp_arr(1,:) = 0._DP
            end if 
            
            status = nf90_inq_varid(nciu%id, nciu%origin_vhy_varname, nciu%origin_vhy_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_vhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar origin_vhy_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%vhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar vhy_varid"  )
            else
               rtemp_arr(2,:) = 0._DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%origin_vhz_varname, nciu%origin_vhz_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%origin_vhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar origin_vhz_varid"  )
            else if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
               call check( nf90_get_var(nciu%id, nciu%vhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar vhz_varid" )
            else
               rtemp_arr(3,:) = 0._DP
            end if 

            do i = 1, npl
               call pl%info(i)%set_value(origin_vh=rtemp_arr(:,plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(origin_vh=rtemp_arr(:,tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%collision_id_varname, nciu%collision_id_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%collision_id_varid, itemp), "netcdf_read_particle_info_system nf90_getvar collision_id_varid"  )
            else
               itemp = 0.0_DP
            end if 

            do i = 1, npl
               call pl%info(i)%set_value(collision_id=itemp(plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(collision_id=itemp(tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%discard_time_varname, nciu%discard_time_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_time_varid, rtemp), "netcdf_read_particle_info_system nf90_getvar discard_time_varid"  )
            else
               rtemp = 0.0_DP
            end if 

            call cb%info%set_value(discard_time=rtemp(1))
            do i = 1, npl
               call pl%info(i)%set_value(discard_time=rtemp(plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(discard_time=rtemp(tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%discard_xhx_varname, nciu%discard_xhx_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_xhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar discard_xhx_varid"  )
            else
               rtemp_arr(1,:) = 0.0_DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%discard_xhy_varname, nciu%discard_xhy_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_xhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar discard_xhy_varid"  )
            else
               rtemp_arr(2,:) = 0.0_DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%discard_xhz_varname, nciu%discard_xhz_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_xhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar discard_xhz_varid"  )
            else
               rtemp_arr(3,:) = 0.0_DP
            end if 

            do i = 1, npl
               call pl%info(i)%set_value(discard_xh=rtemp_arr(:,plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(discard_xh=rtemp_arr(:,tpind(i)))
            end do

            status = nf90_inq_varid(nciu%id, nciu%discard_vhx_varname, nciu%discard_vhx_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_vhx_varid, rtemp_arr(1,:)), "netcdf_read_particle_info_system nf90_getvar discard_vhx_varid"  )
            else
               rtemp_arr(1,:) = 0.0_DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%discard_vhy_varname, nciu%discard_vhy_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_vhy_varid, rtemp_arr(2,:)), "netcdf_read_particle_info_system nf90_getvar discard_vhy_varid"  )
            else
               rtemp_arr(2,:) = 0.0_DP
            end if 

            status = nf90_inq_varid(nciu%id, nciu%discard_vhz_varname, nciu%discard_vhz_varid)
            if (status == nf90_noerr) then
               call check( nf90_get_var(nciu%id, nciu%discard_vhz_varid, rtemp_arr(3,:)), "netcdf_read_particle_info_system nf90_getvar discard_vhz_varid"  )
            else
               rtemp_arr(3,:) = 0.0_DP
            end if 

            do i = 1, npl
               call pl%info(i)%set_value(discard_vh=rtemp_arr(:,plind(i)))
            end do
            do i = 1, ntp
               call tp%info(i)%set_value(discard_vh=rtemp_arr(:,tpind(i)))
            end do
         end if

      end associate

      return
   end subroutine netcdf_read_particle_info_system


   module subroutine netcdf_sync(self)
      !! author: David A. Minton
      !!
      !! Syncrhonize the disk and memory buffer of the NetCDF file (e.g. commit the frame files stored in memory to disk) 
      !!    
      implicit none
      ! Arguments
      class(netcdf_parameters),   intent(inout) :: self !! Parameters used to identify a particular NetCDF dataset

      call check( nf90_sync(self%id), "netcdf_sync nf90_sync"  )

      return
   end subroutine netcdf_sync


   module subroutine netcdf_write_frame_base(self, nciu, param)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Write a frame of output of either test particle or massive body data to the binary output file
      !!    Note: If outputting to orbital elements, but sure that the conversion is done prior to calling this method
      implicit none
      ! Arguments
      class(swiftest_base),       intent(in)    :: self   !! Swiftest particle object
      class(netcdf_parameters),   intent(inout) :: nciu     !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters), intent(inout) :: param  !! Current run configuration parameters
      ! Internals
      integer(I4B)                              :: i, j, tslot, idslot, old_mode
      integer(I4B), dimension(:), allocatable   :: ind
      real(DP), dimension(NDIM)                 :: vh !! Temporary variable to store heliocentric velocity values when converting from pseudovelocity in GR-enabled runs
      real(DP)                                  :: a, e, inc, omega, capom, capm

      call self%write_info(nciu, param)

      tslot = param%ioutput + 1

      call check( nf90_set_fill(nciu%id, nf90_nofill, old_mode), "netcdf_write_frame_base nf90_set_fill"  )
      select type(self)
         class is (swiftest_body)
         associate(n => self%nbody)
            if (n == 0) return

            call util_sort(self%id(1:n), ind)

            do i = 1, n
               j = ind(i)
               idslot = self%id(j) + 1

               !! Convert from pseudovelocity to heliocentric without replacing the current value of pseudovelocity 
               if (param%lgr) call gr_pseudovel2vel(param, self%mu(j), self%xh(:, j), self%vh(:, j), vh(:))

               if ((param%out_form == "XV") .or. (param%out_form == "XVEL")) then
                  call check( nf90_put_var(nciu%id, nciu%xhx_varid, self%xh(1, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var xhx_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%xhy_varid, self%xh(2, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var xhy_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%xhz_varid, self%xh(3, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var xhz_varid"  )
                  if (param%lgr) then !! Convert from pseudovelocity to heliocentric without replacing the current value of pseudovelocity
                     call check( nf90_put_var(nciu%id, nciu%vhx_varid, vh(1), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhx_varid (gr case)"  )
                     call check( nf90_put_var(nciu%id, nciu%vhy_varid, vh(2), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhy_varid (gr case)"  )
                     call check( nf90_put_var(nciu%id, nciu%vhz_varid, vh(3), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhz_varid (gr case)"  )
                     call check( nf90_put_var(nciu%id, nciu%gr_pseudo_vhx_varid, self%vh(1, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var gr_pseudo_vhx_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%gr_pseudo_vhy_varid, self%vh(2, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var gr_pseudo_vhy_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%gr_pseudo_vhz_varid, self%vh(3, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var gr_pseudo_vhz_varid"  )

                  else
                     call check( nf90_put_var(nciu%id, nciu%vhx_varid, self%vh(1, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhx_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%vhy_varid, self%vh(2, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhy_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%vhz_varid, self%vh(3, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var vhz_varid"  )
                  end if
               end if

               if ((param%out_form == "EL") .or. (param%out_form == "XVEL")) then
                  if (param%lgr) then !! For GR-enabled runs, use the true value of velocity computed above
                     call orbel_xv2el(self%mu(j), self%xh(1,j), self%xh(2,j), self%xh(3,j), &
                                       vh(1), vh(2), vh(3), &
                                       a, e, inc, capom, omega, capm)
                  else !! For non-GR runs just convert from the velocity we have
                     call orbel_xv2el(self%mu(j), self%xh(1,j), self%xh(2,j), self%xh(3,j), &
                                       self%vh(1,j), self%vh(2,j), self%vh(3,j), &
                                       a, e, inc, capom, omega, capm)
                  end if
                  call check( nf90_put_var(nciu%id, nciu%a_varid, a, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var a_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%e_varid, e, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var e_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%inc_varid, inc * RAD2DEG, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var inc_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%capom_varid, capom * RAD2DEG, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var capom_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%omega_varid, omega * RAD2DEG, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var omega_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%capm_varid, capm * RAD2DEG, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var capm_varid"  ) 
               end if

               select type(self)  
               class is (swiftest_pl)  ! Additional output if the passed polymorphic object is a massive body
                  call check( nf90_put_var(nciu%id, nciu%Gmass_varid, self%Gmass(j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var Gmass_varid"  )
                  if (param%lrhill_present) then
                     call check( nf90_put_var(nciu%id, nciu%rhill_varid, self%rhill(j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var rhill_varid"  )
                  end if
                  if (param%lclose) call check( nf90_put_var(nciu%id, nciu%radius_varid, self%radius(j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var radius_varid"  )
                  if (param%lrotation) then
                     call check( nf90_put_var(nciu%id, nciu%Ip1_varid, self%Ip(1, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var Ip1_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%Ip2_varid, self%Ip(2, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var Ip2_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%Ip3_varid, self%Ip(3, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var Ip3_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%rotx_varid, self%rot(1, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var rotx_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%roty_varid, self%rot(2, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var roty_varid"  )
                     call check( nf90_put_var(nciu%id, nciu%rotz_varid, self%rot(3, j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var rotz_varid"  )
                  end if
                  ! if (param%ltides) then
                  !    call check( nf90_put_var(nciu%id, nciu%k2_varid, self%k2(j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var k2_varid"  )
                  !    call check( nf90_put_var(nciu%id, nciu%Q_varid, self%Q(j), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var Q_varid"  )
                  ! end if

               end select
            end do
         end associate
      class is (swiftest_cb)
         idslot = self%id + 1
         call check( nf90_put_var(nciu%id, nciu%id_varid, self%id, start=[idslot]), "netcdf_write_frame_base nf90_put_var cb id_varid"  )

         call check( nf90_put_var(nciu%id, nciu%Gmass_varid, self%Gmass, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb Gmass_varid"  )
         if (param%lclose) call check( nf90_put_var(nciu%id, nciu%radius_varid, self%radius, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb radius_varid"  )
         call check( nf90_put_var(nciu%id, nciu%j2rp2_varid, self%j2rp2, start=[tslot]), "netcdf_write_frame_base nf90_put_var cb j2rp2_varid" )
         call check( nf90_put_var(nciu%id, nciu%j4rp4_varid, self%j4rp4, start=[tslot]), "netcdf_write_frame_base nf90_put_var cb j4rp4_varid" )
         if (param%lrotation) then
            call check( nf90_put_var(nciu%id, nciu%Ip1_varid, self%Ip(1), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb Ip1_varid"  )
            call check( nf90_put_var(nciu%id, nciu%Ip2_varid, self%Ip(2), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb Ip2_varid"  )
            call check( nf90_put_var(nciu%id, nciu%Ip3_varid, self%Ip(3), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb Ip3_varid"  )
            call check( nf90_put_var(nciu%id, nciu%rotx_varid, self%rot(1), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb rotx_varid"  )
            call check( nf90_put_var(nciu%id, nciu%roty_varid, self%rot(2), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb roty_varid"  )
            call check( nf90_put_var(nciu%id, nciu%rotz_varid, self%rot(3), start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb rotz_varid"  )
         end if
         ! if (param%ltides) then
         !    call check( nf90_put_var(nciu%id, nciu%k2_varid, self%k2, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb k2_varid"  )
         !    call check( nf90_put_var(nciu%id, nciu%Q_varid, self%Q, start=[idslot, tslot]), "netcdf_write_frame_base nf90_put_var cb Q_varid"  )
         ! end if

      end select
      call check( nf90_set_fill(nciu%id, old_mode, old_mode), "netcdf_write_frame_base nf90_set_fill old_mode"  )

      return
   end subroutine netcdf_write_frame_base


   module subroutine netcdf_write_frame_system(self, nciu, param)
      !! author: The Purdue Swiftest Team - David A. Minton, Carlisle A. Wishard, Jennifer L.L. Pouplin, and Jacob R. Elliott
      !!
      !! Write a frame (header plus records for each massive body and active test particle) to a output binary file
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(inout) :: self  !! Swiftest system object
      class(netcdf_parameters),     intent(inout) :: nciu    !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters),   intent(inout) :: param !! Current run configuration parameters 

      call self%write_hdr(nciu, param)
      call self%cb%write_frame(nciu, param)
      call self%pl%write_frame(nciu, param)
      call self%tp%write_frame(nciu, param)

      return
   end subroutine netcdf_write_frame_system


   module subroutine netcdf_write_info_base(self, nciu, param)
      !! author: Carlisle A. Wishard, Dana Singh, and David A. Minton
      !!
      !! Write all current particle to file
      implicit none
      ! Arguments
      class(swiftest_base),       intent(in)    :: self   !! Swiftest particle object
      class(netcdf_parameters),   intent(inout) :: nciu     !! Parameters used to identify a particular NetCDF dataset
      class(swiftest_parameters), intent(inout) :: param  !! Current run configuration parameters
      ! Internals
      integer(I4B)                              :: i, j, idslot, old_mode
      integer(I4B), dimension(:), allocatable   :: ind
      character(len=NAMELEN)                    :: charstring

      ! This string of spaces of length NAMELEN is used to clear out any old data left behind inside the string variables
      call check( nf90_set_fill(nciu%id, nf90_nofill, old_mode), "netcdf_write_info_base nf90_set_fill nf90_nofill"  )

      select type(self)
         class is (swiftest_body)
         associate(n => self%nbody)
            if (n == 0) return
            call util_sort(self%id(1:n), ind)

            do i = 1, n
               j = ind(i)
               idslot = self%id(j) + 1
               call check( nf90_put_var(nciu%id, nciu%id_varid, self%id(j), start=[idslot]), "netcdf_write_info_base nf90_put_var id_varid"  )

               charstring = trim(adjustl(self%info(j)%name))
               call check( nf90_put_var(nciu%id, nciu%name_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var name_varid"  )

               charstring = trim(adjustl(self%info(j)%particle_type))
               call check( nf90_put_var(nciu%id, nciu%ptype_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var particle_type_varid"  )

               charstring = trim(adjustl(self%info(j)%status))
               call check( nf90_put_var(nciu%id, nciu%status_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var status_varid"  )

               if (param%lclose) then
                  charstring = trim(adjustl(self%info(j)%origin_type))
                  call check( nf90_put_var(nciu%id, nciu%origin_type_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var origin_type_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_time_varid,  self%info(j)%origin_time,  start=[idslot]), "netcdf_write_info_base nf90_put_var origin_time_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_xhx_varid,   self%info(j)%origin_xh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_xhx_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_xhy_varid,   self%info(j)%origin_xh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_xhy_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_xhz_varid,   self%info(j)%origin_xh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_xhz_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_vhx_varid,   self%info(j)%origin_vh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_vhx_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_vhy_varid,   self%info(j)%origin_vh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_vhy_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%origin_vhz_varid,   self%info(j)%origin_vh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var origin_vhz_varid"  )
   
                  call check( nf90_put_var(nciu%id, nciu%collision_id_varid, self%info(j)%collision_id, start=[idslot]), "netcdf_write_info_base nf90_put_var collision_id_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_time_varid, self%info(j)%discard_time, start=[idslot]), "netcdf_write_info_base nf90_put_var discard_time_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_xhx_varid, self%info(j)%discard_xh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_xhx_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_xhy_varid, self%info(j)%discard_xh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_xhy_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_xhz_varid, self%info(j)%discard_xh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_xhz_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_vhx_varid, self%info(j)%discard_vh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_vhx_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_vhy_varid, self%info(j)%discard_vh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_vhy_varid"  )
                  call check( nf90_put_var(nciu%id, nciu%discard_vhz_varid, self%info(j)%discard_vh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var discard_vhz_varid"  )
               end if

            end do
         end associate

      class is (swiftest_cb)
         idslot = self%id + 1
         call check( nf90_put_var(nciu%id, nciu%id_varid, self%id, start=[idslot]), "netcdf_write_info_base nf90_put_var cb id_varid"  )

         charstring = trim(adjustl(self%info%name))
         call check( nf90_put_var(nciu%id, nciu%name_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var cb name_varid"  )

         charstring = trim(adjustl(self%info%particle_type))
         call check( nf90_put_var(nciu%id, nciu%ptype_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var cb ptype_varid"  )

         charstring = trim(adjustl(self%info%status))
         call check( nf90_put_var(nciu%id, nciu%status_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var cb status_varid"  )

         if (param%lclose) then
            charstring = trim(adjustl(self%info%origin_type))
            call check( nf90_put_var(nciu%id, nciu%origin_type_varid, charstring, start=[1, idslot], count=[NAMELEN, 1]), "netcdf_write_info_base nf90_put_var cb origin_type_varid"  )

            call check( nf90_put_var(nciu%id, nciu%origin_time_varid, self%info%origin_time, start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_time_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_xhx_varid, self%info%origin_xh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_xhx_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_xhy_varid, self%info%origin_xh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_xhy_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_xhz_varid, self%info%origin_xh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_xhz_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_vhx_varid, self%info%origin_vh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_vhx_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_vhy_varid, self%info%origin_vh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_vhy_varid"  )
            call check( nf90_put_var(nciu%id, nciu%origin_vhz_varid, self%info%origin_vh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var cb origin_vhz_varid"  )
   
            call check( nf90_put_var(nciu%id, nciu%collision_id_varid, self%info%collision_id, start=[idslot]), "netcdf_write_info_base nf90_put_var cb collision_id_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_time_varid, self%info%discard_time, start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_time_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_xhx_varid, self%info%discard_xh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_xhx_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_xhy_varid, self%info%discard_xh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_xhy_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_xhz_varid, self%info%discard_xh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_xhz_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_vhx_varid, self%info%discard_vh(1), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_vhx_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_vhy_varid, self%info%discard_vh(2), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_vhy_varid"  )
            call check( nf90_put_var(nciu%id, nciu%discard_vhz_varid, self%info%discard_vh(3), start=[idslot]), "netcdf_write_info_base nf90_put_var cb discard_vhz_varid"  )
         end if

      end select

      call check( nf90_set_fill(nciu%id, old_mode, old_mode) )
      return
   end subroutine netcdf_write_info_base


   module subroutine netcdf_write_hdr_system(self, nciu, param) 
      !! author: David A. Minton
      !!
      !! Writes header information (variables that change with time, but not particle id). 
      !! This subroutine significantly improves the output over the original binary file, allowing us to track energy, momentum, and other quantities that 
      !! previously were handled as separate output files.
      implicit none
      ! Arguments
      class(swiftest_nbody_system), intent(in)    :: self  !! Swiftest nbody system object
      class(netcdf_parameters),     intent(inout) :: nciu    !! Parameters used to for writing a NetCDF dataset to file
      class(swiftest_parameters),   intent(inout) :: param !! Current run configuration parameters
      ! Internals
      integer(I4B) :: tslot

      tslot = param%ioutput + 1

      call check( nf90_put_var(nciu%id, nciu%time_varid, self%t, start=[tslot]), "netcdf_write_hdr_system nf90_put_var time_varid"  )
      call check( nf90_put_var(nciu%id, nciu%npl_varid, self%pl%nbody, start=[tslot]), "netcdf_write_hdr_system nf90_put_var npl_varid"  )
      call check( nf90_put_var(nciu%id, nciu%ntp_varid, self%tp%nbody, start=[tslot]), "netcdf_write_hdr_system nf90_put_var ntp_varid"  )
      select type(pl => self%pl)
      class is (symba_pl)
         call check( nf90_put_var(nciu%id, nciu%nplm_varid, pl%nplm, start=[tslot]), "netcdf_write_hdr_system nf90_put_var nplm_varid"  )
      end select

      if (param%lenergy) then
         call check( nf90_put_var(nciu%id, nciu%KE_orb_varid, self%ke_orbit, start=[tslot]), "netcdf_write_hdr_system nf90_put_var KE_orb_varid"  )
         call check( nf90_put_var(nciu%id, nciu%KE_spin_varid, self%ke_spin, start=[tslot]), "netcdf_write_hdr_system nf90_put_var KE_spin_varid"  )
         call check( nf90_put_var(nciu%id, nciu%PE_varid, self%pe, start=[tslot]), "netcdf_write_hdr_system nf90_put_var PE_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_orbx_varid, self%Lorbit(1), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_orbx_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_orby_varid, self%Lorbit(2), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_orby_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_orbz_varid, self%Lorbit(3), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_orbz_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_spinx_varid, self%Lspin(1), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_spinx_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_spiny_varid, self%Lspin(2), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_spiny_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_spinz_varid, self%Lspin(3), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_spinz_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_escapex_varid, self%Lescape(1), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_escapex_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_escapey_varid, self%Lescape(2), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_escapey_varid"  )
         call check( nf90_put_var(nciu%id, nciu%L_escapez_varid, self%Lescape(3), start=[tslot]), "netcdf_write_hdr_system nf90_put_var L_escapez_varid"  )
         call check( nf90_put_var(nciu%id, nciu%Ecollisions_varid, self%Ecollisions, start=[tslot]), "netcdf_write_hdr_system nf90_put_var Ecollisions_varid"  )
         call check( nf90_put_var(nciu%id, nciu%Euntracked_varid, self%Euntracked, start=[tslot]), "netcdf_write_hdr_system nf90_put_var Euntracked_varid"  )
         call check( nf90_put_var(nciu%id, nciu%GMescape_varid, self%GMescape, start=[tslot]), "netcdf_write_hdr_system nf90_put_var GMescape_varid"  )
      end if

      return
   end subroutine netcdf_write_hdr_system

end submodule s_netcdf
