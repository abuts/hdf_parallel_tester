function [fid,group_id,file_h] = create_nxsqw_head(f_name)
% function creates hdf5 file containing nxsqw file header
%
% returns hdf file identifier for data access
%
[v1,v2,v3]= H5.get_libversion();
datem=[datestr(now,31),'+00:00'];
datem(11)='T';
file_attr=struct('NeXus_version','4.3.0 ','file_name',...
    fullfile(f_name),'HDF5_Version',...
    sprintf('%d.%d.%d',v1,v2,v3),'file_time',datem); % time example: 2011-06-23T09:12:44+00:00


%-------------------------------------------------------------------------
% Start writing file
%-------------------------------------------------------------------------
fcpl = H5P.create('H5P_FILE_CREATE');
fapl = H5P.create('H5P_FILE_ACCESS');
fid =  H5F.create(f_name,'H5F_ACC_TRUNC',fcpl,fapl);
%
% make this file look like real nexus
if matlab_version_num()<=7.07
    %pNew->iVID=H5Gopen(pNew->iFID,"/");
    file_h = fid;
    fid = H5G.open(fid,'/');
else
    file_h = [];
end
write_attr_group(fid,file_attr);

% nexus data
group_name = 'Horace_sqw';
group_id = H5G.create(fid,group_name,1000);
write_attr_group(group_id,struct('NX_class','NXentry'));
%-------------------------------------------------------------------------
% write sqw dataset definition
version = '4.0';


write_string_sign(group_id,'definition','SQW','version',version);
[~,hv] = horace_version('-brief');
write_string_sign(group_id,'program_name','horace','version',hv);

H5P.close(fcpl);
H5P.close(fapl);