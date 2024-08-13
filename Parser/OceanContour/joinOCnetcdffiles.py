import xarray as xr
from pathlib import Path

# full path to directory containing the netcdf files
input_netcdf_directory= r'/Users/cow074/code/srs_mooring_data/'
# choose an output filename
output_netcdf_filename = "Joined.VTC.DSEL.AVER.nc"
# select a filename wildcard that matches your files. Typically for avg currents
# it is of the form 'Avg_0*.nc', for processed waves its 'Burst_0*.nc'
glob_pattern = 'Burst_0*AVER*.nc'
# data group name of input files, for avg currents its 'Data/Avg', and for waves its 'Data/Burst'
group_name  = 'Data/Burst'
ncpath = Path(input_netcdf_directory)
flist = sorted(ncpath.glob(glob_pattern))
config = xr.load_dataset(flist[0], group='Config')
nc_file = Path(ncpath, output_netcdf_filename)
ds = xr.open_mfdataset(flist, group=group_name)
config.to_netcdf(nc_file, "w", group="Config", format="NETCDF4")
ds.to_netcdf(nc_file, "a", group=group_name, format="NETCDF4")
ds.close()


# repeat for the WAVES files
# full path to directory containing the netcdf files
input_netcdf_directory= r'/Users/cow074/code/srs_mooring_data/'
# choose an output filename
output_netcdf_filename = "Joined.WAVES.nc"
# select a filename wildcard that matches your files. Typically for avg currents
# it is of the form 'Avg_0*.nc', for processed waves its 'Burst_0*.nc'
glob_pattern = 'Burst_0*WAVES.nc'
# data group name of input files, for avg currents its 'Data/Avg', and for waves its 'Data/Burst'
group_name  = 'Data/Waves'
ncpath = Path(input_netcdf_directory)
flist = sorted(ncpath.glob(glob_pattern))
config = xr.load_dataset(flist[0], group='Config')
nc_file = Path(ncpath, output_netcdf_filename)
ds = xr.open_mfdataset(flist, group=group_name)
config.to_netcdf(nc_file, "w", group="Config", format="NETCDF4")
ds.to_netcdf(nc_file, "a", group=group_name, format="NETCDF4")
ds.close()