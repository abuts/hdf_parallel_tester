function [time,real_sz]=random_hdf_read(filesize,block_size,n_blocks,job_num)
t0 = tic;
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

[fid,group_id] = open_or_create_nxsqw_head(f_name);

% read PIXELS
reader = hdf_pix_group(group_id);
fprintf(' chunk size: %dKPix\n',reader.block_size/1024);
pos = floor((filesize-block_size)*rand(1,n_blocks))+1;
%pos = sort(pos); % this should not and seems indeed does not make any
%difference to the read speed.
real_sz = 0;
for i=1:n_blocks
    cont = reader.read_pixels(pos(i),block_size);
    real_sz  = real_sz+size(cont,2);
end

delete(reader);
H5G.close(group_id);
H5F.close(fid);

time = toc(t0);
