function [time,real_sz]=random_hdf_read(filesize,block_size,n_blocks,job_num,n_call)
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
if ~exist('n_call','var')
    n_call = 0;
end

f_name = sprintf('block_%d.hdf',id);

[fid,group_id] = open_or_create_nxsqw_head(f_name);

% read PIXELS
reader = hdf_pix_group(group_id);
if n_call == 1
    fprintf(' chunk size: %dKPix\n',reader.chunk_size/1024);
end

pos = floor((filesize-block_size)*rand(1,n_blocks))+1;

starts = sort(pos); % this should not and seems indeed does not make any
ends       = starts+block_size;
block_size = ends-starts;
[pos,block_size] = compact_overlapping(starts,block_size);
%difference to the read speed.
real_sz = 0;
% for i=1:numel(pos)
%      cont = reader.read_pixels(pos(i),block_size(i));
%      real_sz  = real_sz+size(cont,2);
% 
% end
while ~isempty(pos)
    [cont,pos,block_size] = reader.read_pixels(pos,block_size);
    real_sz  = real_sz+size(cont,2);
end

delete(reader);
H5G.close(group_id);
H5F.close(fid);

time = toc(t0);
