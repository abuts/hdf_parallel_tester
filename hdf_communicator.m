function [time,size] = hdf_communicator(block_size,n_blocks,job_num)

nl = numlabs;
if ~exist('job_num','var')
    id = labindex-1;
else
    id  = job_num-1;
end
%
t0 = tic;
if id == 0
    f_name = 'targ_file.hdf';
    [fid,group_id] = open_or_create_nxsqw_head(f_name);
    clob1 = onCleanup(@()par_clear({group_id,fid}));
    hdf_w = hdf_pix_group(group_id);
    clobW = onCleanup(@()par_clear({hdf_w,group_id,fid}));
    %
    n_parts = nl-1;
    if n_parts == 0  % serial execution. All input files should be read by serial job.
        n_parts = 5;
        fhr = cell(1,2*n_parts);
        for i=1:n_parts
            f_name = sprintf('block_%d.bin',i);
            
            [fhr{2*(i-1)+1},fhr{2*(i-1)+2}] = open_or_create_nxsqw_head(f_name);
        end
        clobR = onCleanup(@()par_clear(fhr));
        
    else
        fhr = [];
    end
    block = zeros(9,block_size*n_parts);
    
    for i=1:n_blocks
        block = get_block(i,block,n_parts,fhr);
        hdf_w.write_pixels(,block);
    end
else
    
    f_name = sprintf('block_%d.bin',id);
    [fid,gr_id]   =open_or_create_nxsqw_head(f_name);
    hdf_r = hdf_pix_group(gr_id);    
    clob = onCleanup(@()par_clear({hdf_r,gr_id,fid}));
    
    for i=1:n_blocks
        contents = hdf_r.read_pixels((i-1)*block_size,block_size);
        labSend(contents,1,i);
    end
    size = block_size*n_blocks;
    clear('clob');
end
time = toc(t0);

function block = get_block(n_block,block,n_parts,par)

block_size = size(block);
chunk_size = block_size(2)/n_parts;
if isempty(par)
    get_data = @(i)(labReceive(i+1,n_block));
    check_exist = @(i)(labProbe(i+1,n_block));
else
    check_exist = @(i)(true);
    get_data = @(i)(fread(par{i},[chunk_size]));
end

n_received = 0;
while n_received~=n_parts
    for i=1:n_parts
        if check_exist(i)
            block(:,(i-1)*chunk_size+1:i*chunk_size) = get_data(i);
            n_received = n_received+1;
        end
    end
end


function par_clear(fh_list)
for i=1:numel(fh_list)
    delete(fh_list{i});
end