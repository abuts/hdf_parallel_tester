function hdf_writer(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex;
else
    id  = job_num;
end
if id == nl
    return;
end

f_name = sprintf('block_%d.hdf',id);

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
    file = fid;
    fid = H5G.open(fid,'/');
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


% write PIXELS
write_pixels(group_id,id,block_size,n_blocks);

%
% close all and finish
H5G.close(group_id);
H5P.close(fcpl);
H5P.close(fapl);






if exist('file','var')
    H5G.close(fid);
    H5F.close(file);
else
    H5F.close(fid);
end
end

function write_pixels(fid,id,block_size,n_blocks)
% write all pixels data;

group_id = H5G.create(fid,'pixels',100);
write_attr_group(group_id,struct('NX_class','NXdata'));
double_id = H5T.copy('H5T_NATIVE_DOUBLE');

dims = [9,block_size*n_blocks];
chunk_dims = [9,block_size];
h5_dims = fliplr(dims);
h5_maxdims = h5_dims;
chunk_dims  = fliplr(chunk_dims);
dcpl_id = H5P.create('H5P_DATASET_CREATE');
H5P.set_chunk(dcpl_id, chunk_dims);
%     /* Create the dataspace and the chunked dataset */
%     pace_id = H5Screate_simple(2, dset_dims, NULL);
%     dset_id = H5Dcreate(file, dataset, H5T_NATIVE_INT, space_id, dcpl_id, 
%                         H5P_DEFAULT);

fil_space_id = H5S.create_simple(2,h5_dims,h5_maxdims);
mem_space_id = H5S.create_simple(2,chunk_dims,chunk_dims);
dset_id = H5D.create(group_id,'pixels',double_id,fil_space_id,dcpl_id);

%     /* Write to the dataset */
%     buffer = 
%     H5Dwrite(dset_id, H5T_NATIVE_INT, H5S_ALL, H5S_ALL, H5P_DEFAULT, buffer);
% 

contents = id*ones(9,block_size);
for i=1:n_blocks
    contents(2,:) = contents(2,:)*i;
    block_start = [(i-1)*block_size,0];
    H5S.select_hyperslab(fil_space_id,'H5S_SELECT_SET',block_start,[],[],chunk_dims);
    H5D.write(dset_id,'H5ML_DEFAULT',mem_space_id,fil_space_id,'H5P_DEFAULT',contents);    
end



H5S.close(mem_space_id);
H5S.close(fil_space_id);
H5D.close(dset_id);

%
H5T.close(double_id);
H5G.close(group_id);
end
%
function dset_id=write_double_dataset(group_id,ds_name,dataset,double_id)

dims = size(dataset);
h5_dims = fliplr(dims);
h5_maxdims = h5_dims;
nds = numel(dataset);
if dims(1) == 1 || dims(2)==1
    space_id = H5S.create_simple(1,nds,nds);
    dset_id = H5D.create(group_id,ds_name,double_id,space_id,'H5P_DEFAULT');
else
    space_id = H5S.create_simple(2,h5_dims,h5_maxdims);
    dset_id = H5D.create(group_id,ds_name,double_id,space_id,'H5P_DEFAULT');
end
H5D.write(dset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',dataset);
H5S.close(space_id);
end



function write_attr_group(group_id,data)
% write group of string attributes
attr_names = fieldnames(data);
for i=1:numel(attr_names)
    
    an = attr_names{i};
    val = data.(an);
    
    if ischar(val)
        type_id = H5T.copy('H5T_C_S1');
        H5T.set_size(type_id, numel(val));
        %type_id = H5T.create('H5T_STRING',numel(val));
        space_id = H5S.create('H5S_SCALAR');
        %loc_id, name, type_id, space_id, acpl_id
        attr_id = H5A.create(group_id,an,type_id,space_id,'H5P_DEFAULT');
        %attr_id = H5A.create(loc_id, name, type_id, space_id, create_plist)
        H5A.write(attr_id,'H5ML_DEFAULT',val);
        
        H5A.close(attr_id);
        H5S.close(space_id);
        H5T.close(type_id);
    end
end
end

function write_string_sign(group_id,ds_name,name,attr_name,attr_cont)
% write string dataset with possible attribute
% Such structure is used in NeXus e.g. to indicate that this file is nxspe file
% and on number of other occasions
%
% type_id = H5T.copy('H5T_C_S1');
% space_id = H5S.create_simple(1,numel(name),numel(name));
% dataset_id = H5D.create(group_id,ds_name,type_id,space_id,'H5P_DEFAULT');
% %space_id = H5S.create('H5S_SCALAR');
% %dataset_id = H5D.create(group_id,definition,type_id,space_id,'H5P_DEFAULT');
% H5D.write(dataset_id,'H5ML_DEFAULT','H5S_ALL','H5S_ALL','H5P_DEFAULT',name);

filetype = H5T.copy ('H5T_FORTRAN_S1');
H5T.set_size (filetype, numel(name));
memtype = H5T.copy ('H5T_C_S1');
H5T.set_size (memtype, numel(name));

space = H5S.create_simple (1,1, 1);
dataset_id = H5D.create (group_id, ds_name, filetype, space, 'H5P_DEFAULT');
H5D.write (dataset_id, memtype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT', name);

write_attr_group(dataset_id,struct(attr_name,attr_cont));
H5D.close(dataset_id);
H5S.close(space);
H5T.close(filetype);
H5T.close(memtype);
end

