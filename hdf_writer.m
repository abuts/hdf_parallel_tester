function [time,size]=hdf_writer(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex;
else
    id  = job_num;
end
if id == nl
    return;
end
t0 = tic;

f_name = sprintf('block_%d.hdf',id);

[fid,group_id,file] = open_or_create_nxsqw_head(f_name);

% write PIXELS
writer = hdf_pix_group(group_id,n_blocks*block_size,64*1024);
contents = single(id*ones(9,block_size));
for i=1:n_blocks
    contents(2,:) = single(contents(2,:)*i);
    start_pos = (i-1)*block_size+1;
    writer.write_pixels(start_pos,contents)
end
size = block_size*n_blocks;

H5G.close(group_id);
if ~isempty(file)
    H5G.close(fid);
    H5F.close(file);
else
    H5F.close(fid);
end
time = toc(t0);
